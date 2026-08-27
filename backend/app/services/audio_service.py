"""
Audio Processing Service: PCM Chunker, WebRTC VAD & WAV Utilities
"""
import importlib
import io
import logging
import wave
import numpy as np

webrtcvad = None
try:
    if importlib.util.find_spec("webrtcvad") is not None:
        webrtcvad = importlib.import_module("webrtcvad")
except Exception:
    webrtcvad = None

logger = logging.getLogger(__name__)


def pcm_to_wav(
    pcm_bytes: bytes,
    sample_rate: int = 16000,
    channels: int = 1,
) -> bytes:
    """Convert raw PCM-16 LE bytes into an in-memory standard WAV buffer."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit = 2 bytes
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    buf.seek(0)
    return buf.read()


def calculate_audio_rms(pcm_bytes: bytes, channels: int = 1) -> float:
    """Compute normalized RMS energy of 16-bit PCM audio."""
    if not pcm_bytes:
        return 0.0
    try:
        audio = np.frombuffer(pcm_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        if audio.size == 0:
            return 0.0
        if channels > 1:
            trim = audio.size - (audio.size % channels)
            if trim <= 0:
                return 0.0
            audio = audio[:trim].reshape(-1, channels).mean(axis=1)
        return float(np.sqrt(np.mean(audio * audio)))
    except Exception as exc:
        logger.debug(f"RMS calculation failed: {exc}")
        return 0.0


def calculate_signal_quality(pcm_bytes: bytes, channels: int = 1) -> float:
    """Assess signal quality based on RMS level and clipping ratio."""
    if not pcm_bytes:
        return 0.0
    try:
        audio = np.frombuffer(pcm_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        if audio.size == 0:
            return 0.0
        if channels > 1:
            trim = audio.size - (audio.size % channels)
            if trim <= 0:
                return 0.0
            audio = audio[:trim].reshape(-1, channels).mean(axis=1)

        rms = float(np.sqrt(np.mean(audio * audio)))
        clipping = float(np.mean(np.abs(audio) > 0.98))
        rms_score = max(0.0, min(1.0, (rms - 0.005) / 0.06))
        clip_penalty = max(0.0, min(1.0, 1.0 - (clipping * 6.0)))
        return max(0.0, min(1.0, (rms_score * 0.7) + (clip_penalty * 0.3)))
    except Exception:
        return 0.5


def check_speech_vad(pcm_bytes: bytes, sample_rate: int = 16000) -> bool:
    """Detect voice activity in PCM-16 audio buffer using WebRTC VAD or RMS fallback."""
    if not pcm_bytes:
        return False

    if webrtcvad is None or sample_rate not in (8000, 16000, 32000, 48000):
        rms = calculate_audio_rms(pcm_bytes)
        return rms > 0.008

    try:
        vad = webrtcvad.Vad(3)  # Aggressive mode
        frame_duration_ms = 30
        bytes_per_frame = int(sample_rate * (frame_duration_ms / 1000.0) * 2)

        speech_frames = 0
        total_frames = 0

        for i in range(0, len(pcm_bytes) - bytes_per_frame + 1, bytes_per_frame):
            frame = pcm_bytes[i: i + bytes_per_frame]
            if len(frame) == bytes_per_frame:
                total_frames += 1
                if vad.is_speech(frame, sample_rate):
                    speech_frames += 1

        if total_frames == 0:
            return False

        ratio = speech_frames / total_frames
        return ratio >= 0.12
    except Exception as exc:
        logger.debug(f"VAD check fallback: {exc}")
        return calculate_audio_rms(pcm_bytes) > 0.008


def slice_pcm_windows(
    pcm_bytes: bytes,
    sample_rate: int = 16000,
    channels: int = 1,
    window_seconds: float = 4.0,
) -> tuple[list[np.ndarray], int]:
    """
    Extract fixed-length audio windows (float32 [-1, 1]) from PCM buffer.
    Returns (list_of_windows, consumed_byte_count).
    """
    bytes_per_sample = 2 * channels
    samples_per_window = int(sample_rate * window_seconds)
    bytes_per_window = samples_per_window * bytes_per_sample

    if len(pcm_bytes) < bytes_per_window:
        return [], 0

    windows: list[np.ndarray] = []
    total_consumed = 0

    while len(pcm_bytes) - total_consumed >= bytes_per_window:
        chunk = pcm_bytes[total_consumed: total_consumed + bytes_per_window]
        audio = np.frombuffer(chunk, dtype=np.int16).astype(np.float32) / 32768.0
        if channels > 1:
            audio = audio.reshape(-1, channels).mean(axis=1)
        windows.append(audio)
        total_consumed += bytes_per_window

    return windows, total_consumed
