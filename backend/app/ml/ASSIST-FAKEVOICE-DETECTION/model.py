import json
import os
import numpy as np

# Number of samples AASIST expects (4.04 s at 16 kHz)
_AASIST_NB_SAMP = 64600


class AASISTWrapper:
    def __init__(self):
        self.model = None
        self.device = "cpu"
        self.fallback = True
        self._try_load()

    def _try_load(self):
        try:
            import torch
            from aasist import Model  # requires aasist/__init__.py

            base = os.path.dirname(os.path.abspath(__file__))
            config_path = os.path.join(base, "aasist", "config", "AASIST.conf")
            weights_path = os.path.join(base, "aasist", "models", "weights", "AASIST.pth")

            with open(config_path, "r") as f:
                config = json.load(f)

            self.device = "cuda" if torch.cuda.is_available() else "cpu"
            self.model = Model(config["model_config"]).to(self.device)
            self.model.load_state_dict(
                torch.load(weights_path, map_location=self.device)
            )
            self.model.eval()
            self.fallback = False
        except Exception as exc:
            print(f"[AASISTWrapper] Failed to load model, using fallback heuristic. Reason: {exc}")
            self.fallback = True

    def predict(self, audio: np.ndarray, sr: int = 16000) -> float:
        """
        Run inference on a single audio window (1D float32 numpy array at sr).
        Returns the spoof/synthetic probability in [0, 1].
        """
        if self.fallback:
            # deterministic-ish fallback: use simple energy + spectral flatness heuristic
            energy = float(np.mean(np.abs(audio)))
            spec = np.abs(np.fft.rfft(audio * np.hanning(len(audio))))
            flatness = float(np.exp(np.mean(np.log(spec + 1e-9))) / (np.mean(spec) + 1e-9))
            score = min(1.0, max(0.0, 0.5 * flatness + 5.0 * energy))
            return float(score)

        import torch
        import torch.nn.functional as F

        # Pad or trim to the length AASIST was trained on
        if len(audio) < _AASIST_NB_SAMP:
            audio = np.pad(audio, (0, _AASIST_NB_SAMP - len(audio)))
        else:
            audio = audio[:_AASIST_NB_SAMP]

        x = torch.FloatTensor(audio).unsqueeze(0).to(self.device)
        with torch.no_grad():
            _, out = self.model(x)
            # out shape: (1, 2) — index 1 is the spoof/synthetic class
            prob = F.softmax(out, dim=1)[0, 1].item()
        return float(prob)


class DecisionEngine:
    def __init__(self, fake_threshold: float = 0.8, scam_threshold: float = 0.6):
        self.fake_threshold = fake_threshold
        self.scam_threshold = scam_threshold

    def evaluate(self, fake_score: float, scam_score: float) -> str:
        if fake_score > self.fake_threshold and scam_score > self.scam_threshold:
            return "HIGH RISK"
        if fake_score > self.fake_threshold:
            return "POTENTIAL_DEEPFAKE"
        if scam_score > self.scam_threshold:
            return "POTENTIAL_SCAM"
        return "OK"
