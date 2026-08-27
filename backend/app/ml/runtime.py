"""
Model Runtime Service: Coordinates Deepfake Voice Inference & Signal Analysis
"""
import logging
from typing import Any, Optional
import numpy as np

from app.core.config import (
    ASSIST_FAKEVOICE_DIR,
    ASSIST_TARGET_SAMPLE_RATE,
    INTENT_MODEL_PATH,
    VOICE_MODEL_PATH,
)
from app.services.audio_service import (
    calculate_audio_rms,
    calculate_signal_quality,
    check_speech_vad,
)
from app.ml.aasist_runner import AASISTRunner

logger = logging.getLogger(__name__)


class ModelScoringService:
    def __init__(self) -> None:
        self.aasist_runner = AASISTRunner(base_dir=ASSIST_FAKEVOICE_DIR)

    def score_audio_window(
        self,
        audio_window: np.ndarray,
        sample_rate: int = ASSIST_TARGET_SAMPLE_RATE,
    ) -> float:
        """Run AASIST inference on float32 numpy audio window."""
        return self.aasist_runner.predict(audio_window, sample_rate=sample_rate)

    def score(
        self,
        audio_bytes: bytes,
        sample_rate: int = ASSIST_TARGET_SAMPLE_RATE,
        channels: int = 1,
    ) -> dict[str, Any]:
        """Compute full acoustic signal evaluation & AASIST deepfake score."""
        if not audio_bytes:
            return {
                "synthetic_voice_score": 0.0,
                "sample_confidence": 0.0,
                "signal_quality": 0.0,
                "audio_rms": 0.0,
                "has_speech": False,
            }

        rms = calculate_audio_rms(audio_bytes, channels=channels)
        quality = calculate_signal_quality(audio_bytes, channels=channels)
        has_speech = check_speech_vad(audio_bytes, sample_rate=sample_rate)

        # Convert PCM to float32
        audio_float = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        if channels > 1:
            trim = audio_float.size - (audio_float.size % channels)
            if trim > 0:
                audio_float = audio_float[:trim].reshape(-1, channels).mean(axis=1)

        voice_score = self.score_audio_window(audio_float, sample_rate=sample_rate) if has_speech else 0.0

        bytes_per_second = max(2, sample_rate * channels * 2)
        seconds_seen = len(audio_bytes) / float(bytes_per_second)
        sample_confidence = max(0.0, min(1.0, seconds_seen / 3.0))

        if not has_speech or rms < 0.006:
            voice_score = 0.0
            sample_confidence = 0.0

        return {
            "synthetic_voice_score": round(voice_score, 3),
            "sample_confidence": round(sample_confidence, 3),
            "signal_quality": round(quality, 3),
            "audio_rms": round(rms, 6),
            "has_speech": has_speech,
        }

    def status(self) -> dict[str, Any]:
        return {
            "aasist_model": {
                "loaded": self.aasist_runner.loaded,
                "device": self.aasist_runner.device,
                "error": self.aasist_runner.load_error,
            },
            "target_sample_rate": ASSIST_TARGET_SAMPLE_RATE,
        }


# Global singleton scoring service instance
scoring_service = ModelScoringService()
