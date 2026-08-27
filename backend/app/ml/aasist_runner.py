"""
AASIST Deepfake Voice Detection Runner
Loads official AASIST PyTorch architecture and runs inference on raw audio waveforms.
"""
import json
import logging
from pathlib import Path
from typing import Optional
import numpy as np

logger = logging.getLogger(__name__)

# AASIST expects 64,600 samples (4.04 seconds at 16 kHz)
AASIST_NUM_SAMPLES = 64600


class AASISTRunner:
    def __init__(self, base_dir: Optional[str] = None) -> None:
        self.model = None
        self.device = "cpu"
        self.loaded = False
        self.load_error: str = ""
        self._init_model(base_dir)

    def _init_model(self, base_dir_str: Optional[str]) -> None:
        try:
            import torch
            import torch.nn.functional as F

            base_dir = (
                Path(base_dir_str)
                if base_dir_str
                else Path(__file__).resolve().parent / "ASSIST-FAKEVOICE-DETECTION"
            )

            config_path = base_dir / "aasist" / "config" / "AASIST.conf"
            weights_path = base_dir / "aasist" / "models" / "weights" / "AASIST.pth"

            if not config_path.exists() or not weights_path.exists():
                self.load_error = f"Model files missing at {base_dir}"
                logger.warning(self.load_error)
                return

            with open(config_path, "r", encoding="utf-8") as fh:
                config = json.load(fh)

            # Import AASIST model class safely
            from .aasist_model import AASISTModel

            self.device = "cuda" if torch.cuda.is_available() else "cpu"
            self.model = AASISTModel(config["model_config"]).to(self.device)
            state_dict = torch.load(weights_path, map_location=self.device, weights_only=True)
            self.model.load_state_dict(state_dict)
            self.model.eval()
            self.loaded = True
            logger.info(f"AASIST Deepfake Voice model loaded successfully on device: {self.device}")
        except Exception as exc:
            self.load_error = str(exc)
            logger.warning(f"AASIST model initialization fallback: {exc}")
            self.loaded = False

    def predict(self, audio: np.ndarray, sample_rate: int = 16000) -> float:
        """
        Run inference on 1D float32 audio waveform.
        Returns probability of synthetic / deepfake voice [0.0, 1.0].
        """
        if not self.loaded or self.model is None:
            # Clean fallback: calculate spectral flatness and high frequency energy ratio
            return self._heuristic_fallback(audio)

        try:
            import torch
            import torch.nn.functional as F

            # Squeeze / flatten to 1D
            audio_flat = audio.squeeze().astype(np.float32)

            # Pad or truncate to AASIST expected length
            if len(audio_flat) < AASIST_NUM_SAMPLES:
                audio_flat = np.pad(audio_flat, (0, AASIST_NUM_SAMPLES - len(audio_flat)))
            else:
                audio_flat = audio_flat[:AASIST_NUM_SAMPLES]

            tensor = torch.FloatTensor(audio_flat).unsqueeze(0).to(self.device)
            with torch.no_grad():
                _, out = self.model(tensor)
                prob = F.softmax(out, dim=1)[0, 1].item()
            return max(0.0, min(1.0, float(prob)))
        except Exception as exc:
            logger.warning(f"AASIST inference error: {exc}")
            return self._heuristic_fallback(audio)

    def _heuristic_fallback(self, audio: np.ndarray) -> float:
        """Deterministic acoustic feature analysis (Spectral Flatness + Energy)."""
        if audio is None or len(audio) == 0:
            return 0.0
        try:
            energy = float(np.mean(np.abs(audio)))
            if energy < 0.005:
                return 0.0  # Silence
            spec = np.abs(np.fft.rfft(audio * np.hanning(len(audio))))
            flatness = float(np.exp(np.mean(np.log(spec + 1e-9))) / (np.mean(spec) + 1e-9))
            score = 0.5 * flatness + 3.0 * min(0.1, energy)
            return max(0.0, min(1.0, float(score)))
        except Exception:
            return 0.0
