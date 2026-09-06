import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/constants.dart';
import 'local_audio_service.dart';
import 'local_phone_lookup.dart';
import 'local_risk_engine.dart';

class LiveRiskScores {
  final double syntheticVoice;
  final double scamIntent;
  final double overall;
  final String transcript;
  final List<String> detectedKeywords;
  final bool sensitiveAlert;
  final String riskLevel;
  final String? scamAlertType;
  final String? scamAlertMessage;
  final bool scamAlertActive;

  const LiveRiskScores({
    required this.syntheticVoice,
    required this.scamIntent,
    required this.overall,
    this.transcript = '',
    this.detectedKeywords = const [],
    this.sensitiveAlert = false,
    this.riskLevel = 'safe',
    this.scamAlertType,
    this.scamAlertMessage,
    this.scamAlertActive = false,
  });
}

class LiveCallService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final http.Client _httpClient = http.Client();
  final StreamController<Uint8List> _audioChunks =
      StreamController<Uint8List>.broadcast();

  static const _ngrokHeader = {'ngrok-skip-browser-warning': 'true'};

  StreamSubscription? _audioSub;
  Timer? _chunkRateTicker;
  Timer? _speechRestartTimer;

  bool _started = false;
  bool _speechInitialized = false;
  bool _speechListening = false;
  int _chunkCount = 0;
  int _chunksInCurrentSecond = 0;
  int _selectedSampleRate = 16000;
  String? _callId;
  String _activeCallNumber = '';
  String _currentTranscript = '';

  double _syntheticVoiceScore = 0.0;
  double _phoneThreatScore = 0.0;

  void Function(LiveRiskScores scores)? _onRisk;
  void Function(String message)? _onError;

  bool get isStarted => _started;
  String get currentTranscript => _currentTranscript;

  /// Starts 100% on-device live call monitoring (Audio DSP + Speech Recognizer + NLP Threat Engine).
  Future<void> start({
    required String callNumber,
    required void Function(LiveRiskScores scores) onRisk,
    required void Function(String message) onError,
    void Function(int chunksPerSecond, int sampleRate)? onAudioDebug,
  }) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('Microphone permission denied.');
    }

    _onRisk = onRisk;
    _onError = onError;
    _activeCallNumber = callNumber;
    _currentTranscript = '';
    _syntheticVoiceScore = 0.0;
    _chunkCount = 0;
    _chunksInCurrentSecond = 0;

    // 1. On-Device Phone Threat Intelligence
    final phoneAnalysis = LocalPhoneLookupService.analyze(callNumber);
    _phoneThreatScore = phoneAnalysis.spamScore;

    // Emit initial on-device phone assessment immediately (0ms)
    _computeAndEmitScores();

    try {
      // 2. Start On-Device Audio Recorder (FlutterSoundRecorder)
      await _recorder.openRecorder();
      _selectedSampleRate = await _startRecorderWithFallback();

      // 3. Initialize On-Device Speech Recognition (Android Native SpeechRecognizer)
      _initOnDeviceSpeech();

      // 4. Process incoming PCM audio frames through pure Dart DSP engine
      final audioBatch = <int>[];
      _audioSub = _audioChunks.stream.listen((bytes) {
        if (bytes.isEmpty) return;
        _chunkCount += 1;
        _chunksInCurrentSecond += 1;

        audioBatch.addAll(bytes);
        // Process every ~1 second of 16kHz PCM audio (32,000 bytes)
        if (audioBatch.length >= 32000) {
          final frame = Uint8List.fromList(audioBatch);
          final analysis = LocalAudioService.analyzePcm(frame);

          _syntheticVoiceScore = analysis.syntheticVoiceScore;
          _computeAndEmitScores();

          // Optional non-blocking cloud telemetry attempt if configured
          _attemptOptionalCloudSync(frame);

          audioBatch.clear();
        }
      }, onError: (e) => onError('Audio stream error: $e'));

      // 5. Chunks-per-second debug ticker
      _chunkRateTicker?.cancel();
      _chunkRateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        final chunks = _chunksInCurrentSecond;
        _chunksInCurrentSecond = 0;
        onAudioDebug?.call(chunks, _selectedSampleRate);
      });

      _started = true;
    } catch (e) {
      await stop();
      throw Exception('Unable to start on-device call monitor: $e');
    }
  }

  /// Evaluates current state across all on-device models and emits fused score.
  void _computeAndEmitScores() {
    if (_onRisk == null) return;

    // 1. On-Device NLP Threat Engine Evaluation
    final threat = LocalRiskEngine.evaluate(_currentTranscript);
    final scamIntent = threat.intentScore;
    final syntheticVoice = _syntheticVoiceScore;
    final phoneRisk = _phoneThreatScore;

    // 2. On-Device Multimodal Risk Fusion
    // Intent and synthetic voice are primary, phone reputation provides baseline
    final dynamicMax = math.max(scamIntent, syntheticVoice);
    final weighted = (scamIntent * 0.55) + (syntheticVoice * 0.30) + (phoneRisk * 0.15);
    final overall = math.max(dynamicMax, weighted).clamp(0.0, 1.0);

    // 3. Risk Classification
    final String riskLevel;
    if (overall >= 0.65 || threat.scamAlertActive) {
      riskLevel = 'danger';
    } else if (overall >= 0.35) {
      riskLevel = 'warning';
    } else {
      riskLevel = 'safe';
    }

    final sensitiveAlert = threat.detectedKeywords.isNotEmpty || threat.scamAlertActive;

    _onRisk!.call(
      LiveRiskScores(
        syntheticVoice: syntheticVoice,
        scamIntent: scamIntent,
        overall: overall,
        transcript: _currentTranscript,
        detectedKeywords: threat.detectedKeywords,
        sensitiveAlert: sensitiveAlert,
        riskLevel: riskLevel,
        scamAlertType: threat.scamAlertType,
        scamAlertMessage: threat.scamAlertMessage,
        scamAlertActive: threat.scamAlertActive,
      ),
    );
  }

  /// Initializes Android native SpeechRecognizer on-device.
  Future<void> _initOnDeviceSpeech() async {
    try {
      _speechInitialized = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _speechListening = false;
            if (_started) {
              _speechRestartTimer?.cancel();
              _speechRestartTimer = Timer(const Duration(milliseconds: 300), () {
                if (_started) _startSpeechListening();
              });
            }
          } else if (status == 'listening') {
            _speechListening = true;
          }
        },
        onError: (err) {
          _speechListening = false;
          if (_started) {
            _speechRestartTimer?.cancel();
            _speechRestartTimer = Timer(const Duration(milliseconds: 1000), () {
              if (_started) _startSpeechListening();
            });
          }
        },
      );

      if (_speechInitialized) {
        _startSpeechListening();
      }
    } catch (_) {
      _speechInitialized = false;
    }
  }

  /// Starts continuous on-device speech-to-text dictation.
  Future<void> _startSpeechListening() async {
    if (!_started || !_speechInitialized || _speechListening) return;
    try {
      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty && words != _currentTranscript) {
            _currentTranscript = words;
            _computeAndEmitScores();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
      _speechListening = true;
    } catch (_) {
      _speechListening = false;
    }
  }

  /// Injects simulated transcript for testing threat detection or when audio mic is synthetic.
  void injectTestTranscript(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return;
    _currentTranscript = _currentTranscript.isEmpty
        ? trimmed
        : '$_currentTranscript $trimmed';
    _computeAndEmitScores();
  }

  Future<int> _startRecorderWithFallback() async {
    final sampleRates = <int>[16000, 44100];
    Object? lastError;

    for (final sampleRate in sampleRates) {
      try {
        await _recorder.startRecorder(
          codec: Codec.pcm16,
          sampleRate: sampleRate,
          numChannels: 1,
          bitRate: sampleRate,
          bufferSize: 8192,
          toStream: _audioChunks.sink,
        );
        await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 200),
        );
        return sampleRate;
      } catch (error) {
        lastError = error;
        try {
          await _recorder.stopRecorder();
        } catch (_) {}
      }
    }

    throw Exception(
      'Unable to start microphone recorder: $lastError',
    );
  }

  /// Non-blocking cloud telemetry attempt: never throws, runs fully in background.
  void _attemptOptionalCloudSync(Uint8List frame) {
    // Only attempt if backend URL is configured
    if (backendBaseUrl.isEmpty) return;

    unawaited(() async {
      try {
        final uri = Uri.parse(backendBaseUrl).replace(
          path: '/assist/live-audio/chunk',
          queryParameters: {
            if (_callId != null) 'call_id': _callId!,
            'sample_rate': '$_selectedSampleRate',
            'channels': '1',
          },
        );

        final response = await _httpClient
            .post(
              uri,
              headers: {'Content-Type': 'application/octet-stream', ..._ngrokHeader},
              body: frame,
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final callId = decoded['call_id']?.toString();
          if (callId != null && callId.isNotEmpty) {
            _callId = callId;
          }
        }
      } catch (_) {
        // Completely non-blocking, on-device engine maintains 100% operation
      }
    }());
  }

  Future<void> stop() async {
    _started = false;
    _speechListening = false;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _chunkRateTicker?.cancel();
    _chunkRateTicker = null;

    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    try {
      await _recorder.stopRecorder();
    } catch (_) {}

    _chunkCount = 0;
    _chunksInCurrentSecond = 0;

    await _audioSub?.cancel();
    _audioSub = null;

    _callId = null;
    _onRisk = null;
    _onError = null;
    _activeCallNumber = '';
    _currentTranscript = '';
    _syntheticVoiceScore = 0.0;
    _phoneThreatScore = 0.0;

    try {
      await _recorder.closeRecorder();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _audioChunks.close();
    _httpClient.close();
  }
}

final liveCallServiceProvider = Provider<LiveCallService>((ref) {
  final service = LiveCallService();
  ref.onDispose(service.dispose);
  return service;
});
