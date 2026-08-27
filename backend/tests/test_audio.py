"""
Unit tests for Audio Processing Service
"""
import numpy as np
from app.services.audio_service import (
    calculate_audio_rms,
    calculate_signal_quality,
    check_speech_vad,
    pcm_to_wav,
    slice_pcm_windows,
)


def test_calculate_audio_rms_silence():
    silence = bytes([0] * 3200)
    rms = calculate_audio_rms(silence)
    assert rms == 0.0


def test_calculate_audio_rms_sine():
    # 16kHz sine wave 1 second
    sr = 16000
    t = np.linspace(0, 1, sr, endpoint=False)
    sine = (np.sin(2 * np.pi * 440 * t) * 16000).astype(np.int16)
    sine_bytes = sine.tobytes()

    rms = calculate_audio_rms(sine_bytes)
    assert rms > 0.1


def test_pcm_to_wav_conversion():
    pcm = bytes([0, 10, 0, 20] * 100)
    wav_bytes = pcm_to_wav(pcm, sample_rate=16000, channels=1)
    assert wav_bytes.startswith(b"RIFF")
    assert b"WAVE" in wav_bytes[:16]


def test_slice_pcm_windows():
    # 10 seconds of 16kHz audio (16000 * 2 bytes * 10 = 320000 bytes)
    sr = 16000
    total_samples = sr * 10
    raw_data = np.zeros(total_samples, dtype=np.int16).tobytes()

    windows, consumed = slice_pcm_windows(raw_data, sample_rate=sr, channels=1, window_seconds=4.0)
    # 10s / 4s = 2 full windows
    assert len(windows) == 2
    assert consumed == 4 * sr * 2 * 2
    assert len(windows[0]) == 4 * sr
