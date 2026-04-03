import importlib
import importlib.util
import math
import pickle
import sys
from pathlib import Path
from typing import Any, Optional

from ..config import (
    ASSIST_FAKEVOICE_DIR,
    ASSIST_TARGET_SAMPLE_RATE,
    INTENT_MODEL_PATH,
    VOICE_MODEL_PATH,
)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def _safe_prob(raw: Any) -> float:
    if isinstance(raw, (list, tuple)) and raw:
        return _safe_prob(raw[-1])
    if hasattr(raw, "tolist"):
        return _safe_prob(raw.tolist())
    try:
        return _clamp01(float(raw))
    except (TypeError, ValueError):
        return 0.0


def _safe_div(num: float, den: float) -> float:
    if den == 0:
        return 0.0
    return num / den


class GenericModelRunner:
    def __init__(self, model_path: str) -> None:
        self.model_path = model_path
        self.model = self._load_model(model_path)

    def _load_model(self, model_path: str) -> Any:
        path = Path(model_path)
        suffix = path.suffix.lower()

        if suffix in {".pkl", ".pickle"}:
            with path.open("rb") as fh:
                return pickle.load(fh)

        if suffix == ".joblib":
            joblib = importlib.import_module("joblib")
            return joblib.load(path)

        if suffix in {".pt", ".pth"}:
            torch = importlib.import_module("torch")
            model = (
                torch.jit.load(str(path))
                if suffix == ".pt"
                else torch.load(path)
            )
            model.eval()
            return model

        raise ValueError(f"Unsupported model format: {suffix}")

    def predict(self, features: list[float]) -> float:
        model = self.model

        if hasattr(model, "predict_proba"):
            output = model.predict_proba([features])
            return _safe_prob(output[0][-1])

        if hasattr(model, "predict"):
            output = model.predict([features])
            return _safe_prob(output[0])

        if callable(model):
            return _safe_prob(model(features))

        if model.__class__.__module__.startswith("torch"):
            torch = importlib.import_module("torch")
            with torch.no_grad():
                tensor = torch.tensor([features], dtype=torch.float32)
                output = model(tensor)
            return _safe_prob(output)

        raise ValueError(
            "Loaded model does not expose a supported prediction interface"
        )


class ModelScoringService:
    def __init__(self) -> None:
        self._assist_load_error: str = ""
        self._assist_runner = self._load_assist_runner()
        self.voice_runner = self._try_load(VOICE_MODEL_PATH)
        self.intent_runner = self._try_load(INTENT_MODEL_PATH)

    def _resolve_assist_dir(self) -> Path:
        if ASSIST_FAKEVOICE_DIR.strip():
            return Path(ASSIST_FAKEVOICE_DIR.strip())
        return Path(__file__).resolve().parent / "ASSIST-FAKEVOICE-DETECTION"

    def _load_assist_runner(self) -> Any:
        assist_dir = self._resolve_assist_dir()
        model_file = assist_dir / "model.py"
        if not assist_dir.exists() or not model_file.exists():
            self._assist_load_error = "ASSIST directory or model.py not found"
            return None

        try:
            assist_dir_str = str(assist_dir)
            if assist_dir_str not in sys.path:
                sys.path.insert(0, assist_dir_str)

            spec = importlib.util.spec_from_file_location(
                "assist_fakevoice_model",
                str(model_file),
            )
            if spec is None or spec.loader is None:
                return None
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.AASISTWrapper()
        except Exception as exc:
            self._assist_load_error = str(exc)
            print(f"[ASSIST LOAD] Failed to initialize AASISTWrapper: {exc}")
            return None

    def _try_load(self, path: str) -> Optional[GenericModelRunner]:
        if not path.strip():
            return None
        try:
            return GenericModelRunner(path.strip())
        except Exception as exc:
            print(f"[MODEL LOAD] Failed to load '{path}': {exc}")
            return None

    def _extract_features(self, audio_bytes: bytes) -> list[float]:
        if not audio_bytes:
            return [0.0] * 10

        sample = audio_bytes[:4096]
        total = len(sample)
        mean = sum(sample) / total
        centered = [b - mean for b in sample]
        variance = sum(v * v for v in centered) / total
        energy = sum(abs(v) for v in centered) / total
        p95_index = max(0, int(total * 0.95) - 1)
        sorted_values = sorted(sample)
        p95 = sorted_values[p95_index]
        zero_crossings = 0
        prev = centered[0]
        for value in centered[1:]:
            if (prev < 0 <= value) or (prev >= 0 > value):
                zero_crossings += 1
            prev = value

        return [
            total / 4096.0,
            mean / 255.0,
            min(sample) / 255.0,
            max(sample) / 255.0,
            variance / (255.0 * 255.0),
            energy / 255.0,
            p95 / 255.0,
            zero_crossings / max(1.0, total - 1),
            math.log1p(sum(sample)) / 10.0,
            (sum(sample[: total // 2]) / max(1, total // 2)) / 255.0,
        ]

    def _fallback_voice(self, audio_bytes: bytes) -> float:
        if not audio_bytes:
            return 0.08
        entropy_like = sum(audio_bytes[:512]) % 100
        return _clamp01(max(0.05, min(0.98, entropy_like / 100)))

    def _fallback_intent(self, audio_bytes: bytes) -> float:
        return 0.0

    def _signal_quality(
        self,
        audio_bytes: bytes,
        channels: int,
    ) -> float:
        if not audio_bytes:
            return 0.0
        try:
            np_module = importlib.import_module("numpy")
            audio = (
                np_module.frombuffer(audio_bytes, dtype=np_module.int16)
                .astype(np_module.float32)
                / 32768.0
            )
            if audio.size == 0:
                return 0.0
            resolved_channels = max(1, int(channels))
            if resolved_channels > 1:
                trim = audio.size - (audio.size % resolved_channels)
                if trim <= 0:
                    return 0.0
                audio = (
                    audio[:trim]
                    .reshape(-1, resolved_channels)
                    .mean(axis=1)
                )

            rms = float(np_module.sqrt(np_module.mean(audio * audio)))
            clipping = float(np_module.mean(np_module.abs(audio) > 0.98))
            rms_score = _clamp01((rms - 0.005) / 0.06)
            clip_penalty = _clamp01(1.0 - (clipping * 6.0))
            return _clamp01((rms_score * 0.7) + (clip_penalty * 0.3))
        except Exception:
            return 0.5

    def _audio_rms(self, audio_bytes: bytes, channels: int) -> float:
        if not audio_bytes:
            return 0.0
        try:
            np_module = importlib.import_module("numpy")
            audio = (
                np_module.frombuffer(audio_bytes, dtype=np_module.int16)
                .astype(np_module.float32)
                / 32768.0
            )
            if audio.size == 0:
                return 0.0
            resolved_channels = max(1, int(channels))
            if resolved_channels > 1:
                trim = audio.size - (audio.size % resolved_channels)
                if trim <= 0:
                    return 0.0
                audio = (
                    audio[:trim]
                    .reshape(-1, resolved_channels)
                    .mean(axis=1)
                )
            rms = float(np_module.sqrt(np_module.mean(audio * audio)))
            return max(0.0, rms)
        except Exception:
            return 0.0

    def _voice_with_assist(
        self,
        audio_bytes: bytes,
        sample_rate: int,
        channels: int,
    ) -> Optional[float]:
        if self._assist_runner is None or not audio_bytes:
            return None

        try:
            np_module = importlib.import_module("numpy")
            audio = (
                np_module.frombuffer(audio_bytes, dtype=np_module.int16)
                .astype(np_module.float32)
                / 32768.0
            )
            if audio.size == 0:
                return None

            resolved_channels = max(1, int(channels))
            if resolved_channels > 1:
                trim = audio.size - (audio.size % resolved_channels)
                if trim <= 0:
                    return None
                audio = (
                    audio[:trim]
                    .reshape(-1, resolved_channels)
                    .mean(axis=1)
                )

            resolved_sr = max(1, int(sample_rate))
            if resolved_sr != ASSIST_TARGET_SAMPLE_RATE:
                librosa = importlib.import_module("librosa")
                audio = librosa.resample(
                    audio,
                    orig_sr=resolved_sr,
                    target_sr=ASSIST_TARGET_SAMPLE_RATE,
                )
                resolved_sr = ASSIST_TARGET_SAMPLE_RATE

            score = self._assist_runner.predict(audio, sr=resolved_sr)
            return _clamp01(float(score))
        except Exception as exc:
            print(f"[ASSIST SCORE] Falling back due to error: {exc}")
            return None

    def score(
        self,
        audio_bytes: bytes,
        sample_rate: int = ASSIST_TARGET_SAMPLE_RATE,
        channels: int = 1,
    ) -> dict[str, float | str]:
        features = self._extract_features(audio_bytes)

        voice = self._voice_with_assist(
            audio_bytes=audio_bytes,
            sample_rate=sample_rate,
            channels=channels,
        )
        if voice is None:
            voice = (
                self.voice_runner.predict(features)
                if self.voice_runner is not None
                else self._fallback_voice(audio_bytes)
            )

        bytes_per_second = max(2, int(sample_rate) * max(1, int(channels)) * 2)
        seconds_seen = _safe_div(
            float(len(audio_bytes)),
            float(bytes_per_second),
        )
        sample_confidence = _clamp01(seconds_seen / 3.0)
        signal_quality = self._signal_quality(audio_bytes, channels=channels)
        rms = self._audio_rms(audio_bytes, channels=channels)
        no_voice_detected = rms < 0.007

        if no_voice_detected:
            sample_confidence = 0.0

        voice_adjusted = _clamp01(
            (voice * sample_confidence) + (0.5 * (1.0 - sample_confidence))
        )
        voice_adjusted = _clamp01(
            (voice_adjusted * 0.85) + (signal_quality * 0.15)
        )

        if no_voice_detected:
            voice_adjusted = 0.0

        intent = (
            self.intent_runner.predict(features)
            if self.intent_runner is not None
            else self._fallback_intent(audio_bytes)
        )

        overall = _clamp01((voice_adjusted * 0.55) + (intent * 0.45))
        label = (
            "danger"
            if overall >= 0.65
            else ("warning" if overall >= 0.35 else "safe")
        )

        return {
            "synthetic_voice_score": round(voice_adjusted, 3),
            "synthetic_voice_raw": round(voice, 3),
            "sample_confidence": round(sample_confidence, 3),
            "signal_quality": round(signal_quality, 3),
            "audio_rms": round(rms, 6),
            "no_voice_detected": no_voice_detected,
            "scam_intent_score": round(intent, 3),
            "overall_score": round(overall, 3),
            "label": label,
        }

    def status(self) -> dict[str, Any]:
        assist_dir = self._resolve_assist_dir()
        return {
            "assist_fakevoice": {
                "loaded": self._assist_runner is not None,
                "fallback": bool(
                    getattr(self._assist_runner, "fallback", True)
                )
                if self._assist_runner is not None
                else True,
                "path": str(assist_dir),
                "error": self._assist_load_error,
            },
            "voice_model": {
                "loaded": self.voice_runner is not None,
                "path": VOICE_MODEL_PATH,
            },
            "intent_model": {
                "loaded": self.intent_runner is not None,
                "path": INTENT_MODEL_PATH,
            },
            "target_sample_rate": ASSIST_TARGET_SAMPLE_RATE,
        }
