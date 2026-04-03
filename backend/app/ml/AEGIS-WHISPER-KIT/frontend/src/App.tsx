import { useRef, useState } from 'react';
import { AlertTriangle, CheckCircle2, MessageSquare } from 'lucide-react';

type BackendScore = {
  riskLevel: string;
  overallScore: number;
  intentScore: number;
  intentSource: string;
  transcript: string;
  keywords: string[];
};

function isDangerRisk(level: string): boolean {
  const normalized = level.toLowerCase();
  return normalized === 'danger' || normalized === 'high';
}

function toBase64(buffer: ArrayBuffer): string {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let idx = 0; idx < len; idx += 1) {
    binary += String.fromCharCode(bytes[idx]);
  }
  return btoa(binary);
}

function floatTo16BitPCM(input: Float32Array): ArrayBuffer {
  const output = new ArrayBuffer(input.length * 2);
  const view = new DataView(output);
  for (let idx = 0; idx < input.length; idx += 1) {
    let sample = Math.max(-1, Math.min(1, input[idx]));
    sample = sample < 0 ? sample * 0x8000 : sample * 0x7fff;
    view.setInt16(idx * 2, sample, true);
  }
  return output;
}

export default function App() {
  const [sttUrl, setSttUrl] = useState('ws://127.0.0.1:8002/asr');
  const [backendUrl, setBackendUrl] = useState('ws://127.0.0.1:8000/assist/live-audio');
  const [running, setRunning] = useState(false);
  const [status, setStatus] = useState('idle');
  const [interimText, setInterimText] = useState('');
  const [finalText, setFinalText] = useState('');
  const [backendScore, setBackendScore] = useState<BackendScore | null>(null);
  const [errorText, setErrorText] = useState('');

  const sttWsRef = useRef<WebSocket | null>(null);
  const backendWsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const sourceNodeRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const processorNodeRef = useRef<ScriptProcessorNode | null>(null);
  const lastTranscriptSentRef = useRef('');

  const stopAll = () => {
    try {
      processorNodeRef.current?.disconnect();
      sourceNodeRef.current?.disconnect();
    } catch {
    }
    processorNodeRef.current = null;
    sourceNodeRef.current = null;

    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
    }

    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }

    if (sttWsRef.current) {
      sttWsRef.current.close();
      sttWsRef.current = null;
    }

    if (backendWsRef.current) {
      backendWsRef.current.close();
      backendWsRef.current = null;
    }

    setRunning(false);
    setStatus('stopped');
  };

  const start = async () => {
    setErrorText('');
    setStatus('connecting');
    setInterimText('');
    setFinalText('');
    setBackendScore(null);
    lastTranscriptSentRef.current = '';

    const backendWs = new WebSocket(backendUrl);
    backendWsRef.current = backendWs;

    backendWs.onopen = () => {
      backendWs.send(JSON.stringify({
        type: 'meta',
        meta: {
          sample_rate: 16000,
          channels: 1,
          call_number: 'localhost-session',
        },
      }));
    };

    backendWs.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (typeof data.overall_score === 'number') {
          setBackendScore({
            riskLevel: String(data.risk_level || 'unknown'),
            overallScore: Number(data.overall_score || 0),
            intentScore: Number(data.scam_intent_score || 0),
            intentSource: String(data.intent_source || 'none'),
            transcript: String(data.transcript || ''),
            keywords: Array.isArray(data.detected_keywords) ? data.detected_keywords : [],
          });
        }
      } catch {
      }
    };

    backendWs.onerror = () => {
      setErrorText('Backend websocket connection failed. Start backend on 127.0.0.1:8000 first.');
    };

    const sttWs = new WebSocket(sttUrl);
    sttWs.binaryType = 'arraybuffer';
    sttWsRef.current = sttWs;

    sttWs.onopen = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const context = new AudioContext({ sampleRate: 16000 });
        const source = context.createMediaStreamSource(stream);
        const processor = context.createScriptProcessor(4096, 1, 1);

        processor.onaudioprocess = (audioEvent) => {
          const floatData = audioEvent.inputBuffer.getChannelData(0);
          const pcmBuffer = floatTo16BitPCM(floatData);

          if (sttWsRef.current?.readyState === WebSocket.OPEN) {
            sttWsRef.current.send(pcmBuffer);
          }
          if (backendWsRef.current?.readyState === WebSocket.OPEN) {
            backendWsRef.current.send(JSON.stringify({
              type: 'chunk',
              pcm_base64: toBase64(pcmBuffer),
            }));
          }
        };

        source.connect(processor);
        processor.connect(context.destination);

        mediaStreamRef.current = stream;
        audioContextRef.current = context;
        sourceNodeRef.current = source;
        processorNodeRef.current = processor;
        setRunning(true);
        setStatus('running');
      } catch (error) {
        setErrorText(`Microphone error: ${String(error)}`);
        stopAll();
      }
    };

    sttWs.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        if (Array.isArray(data.lines)) {
          const merged = data.lines
            .map((line: any) => (line?.text ?? '').toString().trim())
            .filter((text: string) => text.length > 0)
            .join(' ')
            .trim();

          if (merged) {
            setFinalText(merged);
            setInterimText('');

            if (
              merged !== lastTranscriptSentRef.current
              && backendWsRef.current?.readyState === WebSocket.OPEN
            ) {
              backendWsRef.current.send(JSON.stringify({
                type: 'transcript',
                text: merged,
              }));
              lastTranscriptSentRef.current = merged;
            }
          }
        }

        if (typeof data.buffer_transcription === 'string' && data.buffer_transcription.trim()) {
          setInterimText(data.buffer_transcription.trim());
        }
      } catch {
      }
    };

    sttWs.onerror = () => {
      setErrorText('STT websocket connection failed. Start localhost STT server on 127.0.0.1:8002 first.');
      stopAll();
    };

    sttWs.onclose = () => {
      if (running) {
        setStatus('stt-disconnected');
      }
    };
  };

  return (
    <div style={{ padding: '2rem', maxWidth: '980px', margin: '0 auto', fontFamily: 'sans-serif' }}>
      <h1 style={{ fontSize: '1.6rem', marginBottom: '1rem' }}>Localhost STT + AEGIS Risk Monitor</h1>

      <div style={{ display: 'grid', gap: '0.75rem', marginBottom: '1rem' }}>
        <label>
          STT WebSocket
          <input
            value={sttUrl}
            onChange={(event) => setSttUrl(event.target.value)}
            style={{ width: '100%', padding: '0.5rem', borderRadius: '6px', border: '1px solid #ccc' }}
          />
        </label>
        <label>
          Backend WebSocket
          <input
            value={backendUrl}
            onChange={(event) => setBackendUrl(event.target.value)}
            style={{ width: '100%', padding: '0.5rem', borderRadius: '6px', border: '1px solid #ccc' }}
          />
        </label>
      </div>

      <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '1rem' }}>
        <button
          onClick={start}
          disabled={running}
          style={{ padding: '0.65rem 1.25rem', borderRadius: '6px', border: 'none', background: '#2563eb', color: '#fff', fontWeight: 600 }}
        >
          Start
        </button>
        <button
          onClick={stopAll}
          disabled={!running}
          style={{ padding: '0.65rem 1.25rem', borderRadius: '6px', border: '1px solid #d1d5db', background: '#fff', fontWeight: 600 }}
        >
          Stop
        </button>
        <div style={{ alignSelf: 'center', color: '#374151' }}>Status: {status}</div>
      </div>

      {errorText && (
        <div style={{ background: '#fef2f2', border: '1px solid #ef4444', color: '#991b1b', padding: '0.75rem', borderRadius: '8px', marginBottom: '1rem' }}>
          {errorText}
        </div>
      )}

      <div style={{ background: '#111827', color: '#f9fafb', padding: '1rem', borderRadius: '10px', marginBottom: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
          <MessageSquare size={18} />
          <strong>Transcription</strong>
        </div>
        <div style={{ opacity: 0.95 }}>{finalText || 'No finalized transcript yet.'}</div>
        {interimText && <div style={{ marginTop: '0.5rem', opacity: 0.65 }}>Interim: {interimText}</div>}
      </div>

      {backendScore ? (
        <div
          style={{
            borderRadius: '10px',
            padding: '1rem',
            border: `2px solid ${isDangerRisk(backendScore.riskLevel) ? '#ef4444' : '#22c55e'}`,
            background: isDangerRisk(backendScore.riskLevel) ? '#fef2f2' : '#f0fdf4',
            color: isDangerRisk(backendScore.riskLevel) ? '#7f1d1d' : '#14532d',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
            {isDangerRisk(backendScore.riskLevel) ? <AlertTriangle size={20} /> : <CheckCircle2 size={20} />}
            <strong>{isDangerRisk(backendScore.riskLevel) ? 'SCAM RISK DETECTED' : 'LOW RISK'}</strong>
          </div>
          <div>Overall Score: {(backendScore.overallScore * 100).toFixed(1)}%</div>
          <div>Intent Score: {(backendScore.intentScore * 100).toFixed(1)}% ({backendScore.intentSource})</div>
          {backendScore.keywords.length > 0 && (
            <div>Keywords: {backendScore.keywords.join(', ')}</div>
          )}
        </div>
      ) : (
        <div style={{ color: '#6b7280' }}>Waiting for backend risk score...</div>
      )}
    </div>
  );
}
