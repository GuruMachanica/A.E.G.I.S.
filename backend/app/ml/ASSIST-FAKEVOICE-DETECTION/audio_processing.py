import numpy as np
import librosa


def process_buffer_to_windows(buffer_bytes: bytes, sample_rate: int, channels: int = 1, fmt: str = "int16", window_seconds: int = 4, target_sr: int = 16000):
    """
    Convert raw PCM bytes into one or more 4s windows resampled to target_sr and mono.

    Expects PCM `int16` by default. Returns list of 1D float32 numpy arrays at `target_sr`.
    """
    if not buffer_bytes:
        return []

    if fmt != "int16":
        raise ValueError("Only int16 PCM is supported in this helper")

    # Convert bytes to int16 samples
    audio = np.frombuffer(buffer_bytes, dtype=np.int16).astype(np.float32) / 32768.0

    if channels > 1:
        if audio.size % channels != 0:
            # truncate incomplete frame
            audio = audio[: -(audio.size % channels)]
        audio = audio.reshape(-1, channels)
        audio = np.mean(audio, axis=1)

    # Resample to target_sr if needed
    if sample_rate != target_sr:
        audio = librosa.resample(audio, orig_sr=sample_rate, target_sr=target_sr)

    window_len = int(window_seconds * target_sr)
    windows = []
    total = audio.shape[0]
    start = 0
    while start + window_len <= total:
        w = audio[start : start + window_len].astype(np.float32)
        windows.append(w)
        start += window_len

    return windows
