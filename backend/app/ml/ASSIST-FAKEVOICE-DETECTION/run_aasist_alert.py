import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from model import AASISTWrapper, DecisionEngine


def load_audio_mono_float(path: Path) -> tuple[np.ndarray, int]:
    audio, sample_rate = sf.read(str(path), dtype="float32")
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)
    return audio.astype(np.float32), int(sample_rate)


def resample_if_needed(audio: np.ndarray, source_sr: int, target_sr: int) -> np.ndarray:
    if source_sr == target_sr:
        return audio
    import librosa

    return librosa.resample(audio, orig_sr=source_sr, target_sr=target_sr).astype(np.float32)


def split_windows(audio: np.ndarray, sample_rate: int, window_seconds: float) -> list[np.ndarray]:
    window_len = int(sample_rate * window_seconds)
    if window_len <= 0:
        raise ValueError("window_seconds must be greater than 0")

    windows: list[np.ndarray] = []
    start = 0
    while start + window_len <= len(audio):
        windows.append(audio[start : start + window_len].astype(np.float32))
        start += window_len
    return windows


def _record_from_microphone(
    duration: float,
    sample_rate: int,
    channels: int = 1,
    device_index: int | None = None,
) -> np.ndarray:
    if duration <= 0:
        raise ValueError("--duration must be greater than 0")

    try:
        import pyaudio
    except ImportError as exc:
        raise RuntimeError(
            "Microphone mode requires pyaudio. Install with: pip install pyaudio"
        ) from exc

    chunk_frames = int(sample_rate * 0.2)  # 200ms chunks
    total_frames = int(sample_rate * duration)
    collected = 0
    frames: list[bytes] = []

    pa = pyaudio.PyAudio()
    try:
        stream = pa.open(
            format=pyaudio.paInt16,
            channels=channels,
            rate=sample_rate,
            input=True,
            input_device_index=device_index,
            frames_per_buffer=chunk_frames,
        )
    except Exception as exc:
        pa.terminate()
        raise RuntimeError(f"Failed to open microphone stream: {exc}") from exc

    print(f"🎙 Recording {duration:.1f}s from microphone at {sample_rate} Hz...")
    try:
        while collected < total_frames:
            need = min(chunk_frames, total_frames - collected)
            chunk = stream.read(need, exception_on_overflow=False)
            frames.append(chunk)
            collected += need
    finally:
        stream.stop_stream()
        stream.close()
        pa.terminate()

    pcm = np.frombuffer(b"".join(frames), dtype=np.int16).astype(np.float32) / 32768.0
    if channels > 1:
        trim = len(pcm) - (len(pcm) % channels)
        pcm = pcm[:trim].reshape(-1, channels).mean(axis=1)
    return pcm.astype(np.float32)


def _list_microphones() -> None:
    try:
        import pyaudio
    except ImportError:
        print("pyaudio not installed. Install with: pip install pyaudio")
        return

    pa = pyaudio.PyAudio()
    try:
        count = pa.get_device_count()
        print("Available audio input devices:")
        for idx in range(count):
            info = pa.get_device_info_by_index(idx)
            if int(info.get("maxInputChannels", 0)) > 0:
                print(
                    f"  index={idx} name={info.get('name')} "
                    f"max_input_channels={int(info.get('maxInputChannels', 0))}"
                )
    finally:
        pa.terminate()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run AASIST on a WAV file or microphone audio and print alert summary")
    parser.add_argument("audio_path", nargs="?", type=str, help="Path to WAV/PCM audio file")
    parser.add_argument("--mic", action="store_true", help="Record from microphone instead of reading a file")
    parser.add_argument("--duration", type=float, default=5.0, help="Recording duration in seconds for --mic")
    parser.add_argument("--mic-device-index", type=int, default=None, help="Microphone device index for --mic")
    parser.add_argument(
        "--save-recording",
        type=str,
        default="mic_input.wav",
        help="Where to save recorded microphone audio when using --mic",
    )
    parser.add_argument("--list-mics", action="store_true", help="List available microphone devices and exit")
    parser.add_argument("--window-seconds", type=float, default=4.0, help="Window size in seconds")
    parser.add_argument("--target-sr", type=int, default=16000, help="Target sample rate for model")
    parser.add_argument("--fake-threshold", type=float, default=0.8, help="Deepfake alert threshold")
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output",
    )
    args = parser.parse_args()

    if args.list_mics:
        _list_microphones()
        return

    if args.mic and args.audio_path:
        raise ValueError("Use either a file path or --mic, not both")
    if not args.mic and not args.audio_path:
        raise ValueError("Provide audio_path or use --mic")

    if args.mic:
        audio = _record_from_microphone(
            duration=args.duration,
            sample_rate=args.target_sr,
            channels=1,
            device_index=args.mic_device_index,
        )
        source_sr = args.target_sr
        audio_path = Path(args.save_recording)
        sf.write(str(audio_path), audio, source_sr, subtype="PCM_16")
        print(f"Saved recording to {audio_path}")
    else:
        audio_path = Path(args.audio_path)
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
        audio, source_sr = load_audio_mono_float(audio_path)

    audio = resample_if_needed(audio, source_sr=source_sr, target_sr=args.target_sr)
    windows = split_windows(audio, sample_rate=args.target_sr, window_seconds=args.window_seconds)

    if not windows:
        raise ValueError(
            f"Audio too short. Need at least {args.window_seconds:.2f}s. "
            f"Got {len(audio) / args.target_sr:.2f}s after resample."
        )

    model = AASISTWrapper()
    decision = DecisionEngine(fake_threshold=args.fake_threshold, scam_threshold=1.1)

    scores: list[float] = []
    alerts: list[str] = []
    for index, window in enumerate(windows, start=1):
        fake_score = float(model.predict(window, sr=args.target_sr))
        alert = decision.evaluate(fake_score, scam_score=0.0)
        scores.append(fake_score)
        alerts.append(alert)
        if not args.json:
            print(f"window={index:02d} fake_score={fake_score:.6f} alert={alert}")

    max_score = float(np.max(scores))
    mean_score = float(np.mean(scores))
    final_alert = "POTENTIAL_DEEPFAKE" if any(item == "POTENTIAL_DEEPFAKE" for item in alerts) else "OK"
    is_ai_voice = final_alert == "POTENTIAL_DEEPFAKE"
    classification = "AI" if is_ai_voice else "HUMAN"

    summary = {
        "audio_path": str(audio_path),
        "source_sample_rate": source_sr,
        "target_sample_rate": args.target_sr,
        "windows": len(windows),
        "max_fake_score": max_score,
        "mean_fake_score": mean_score,
        "threshold": args.fake_threshold,
        "final_alert": final_alert,
        "is_ai_voice": is_ai_voice,
        "classification": classification,
        "model_fallback": model.fallback,
    }

    if args.json:
        print(json.dumps(summary))
    else:
        print("-" * 50)
        print(
            "SUMMARY "
            f"windows={summary['windows']} "
            f"max_fake_score={summary['max_fake_score']:.6f} "
            f"mean_fake_score={summary['mean_fake_score']:.6f} "
            f"threshold={summary['threshold']:.3f} "
            f"model_fallback={summary['model_fallback']}"
        )
        print(f"FINAL ALERT: {summary['final_alert']}")
        print(f"CLASSIFICATION: {summary['classification']}")


if __name__ == "__main__":
    main()
