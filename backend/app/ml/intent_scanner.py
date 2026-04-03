import json
import re
from typing import Any
from urllib import request

from ..config import (
    INTENT_FUSION_WEIGHT,
    SARVAM_API_KEY,
    SARVAM_ENABLED,
    SARVAM_ENDPOINT,
    SARVAM_TIMEOUT_SEC,
    VOICE_FUSION_WEIGHT,
)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def _find_numeric_score(payload: Any) -> float | None:
    keys = {
        "risk_score",
        "scam_intent_score",
        "score",
        "probability",
        "risk_probability",
        "riskProbability",
    }

    if isinstance(payload, dict):
        for key, value in payload.items():
            if key in keys:
                try:
                    return _clamp01(float(value))
                except Exception:
                    pass
            nested = _find_numeric_score(value)
            if nested is not None:
                return nested
    elif isinstance(payload, list):
        for item in payload:
            nested = _find_numeric_score(item)
            if nested is not None:
                return nested
    return None


class IntentRiskScanner:
    _high_risk_patterns = [
        r"\botp\b",
        r"\bpin\b",
        r"\bcvv\b",
        r"\bpassword\b",
        r"credit\s*card",
        r"bank\s*account",
        r"ifsc",
        r"kyc",
        r"aadhaar|aadhar|आधार",
        r"pan\s*card|पैन",
        r"urgent|immediately|right\s*now",
        r"\bmoney\b|पैसे|रुपये|रकम",
        r"paisa|paise|rupaye|rupay|amount",
        r"transfer\s*money|send\s*money",
        r"transfer|bhejo|bhjdo|de\s*do",
        r"reward\s*claim|lottery|jackpot",
        r"block\s*your\s*account|freeze\s*account",
        r"verification\s*code",
        r"upi\s*pin",
        r"रकम\s*भेजो|पैसे\s*भेजो",
        r"अभी\s*करो|तुरंत",
        r"खाता\s*ब्लॉक",
    ]

    def __init__(self) -> None:
        self.enabled = SARVAM_ENABLED and bool(
            SARVAM_API_KEY and SARVAM_ENDPOINT
        )

    def _fallback_score(self, text: str) -> float:
        lowered = text.lower()
        hits = 0
        for pattern in self._high_risk_patterns:
            if re.search(pattern, lowered):
                hits += 1

        otp_pattern = (
            r"\botp\b|verification\s*code|"
            r"upi\s*pin|\bpin\b|\bcvv\b|"
            r"otp\s*batao|otp\s*do"
        )
        money_pattern = (
            r"\bmoney\b|transfer\s*money|"
            r"send\s*money|transfer|paisa|paise|"
            r"rupaye|रुपये|रकम|पैसे|bhejo"
        )
        has_otp_like = bool(re.search(otp_pattern, lowered))
        has_money_like = bool(re.search(money_pattern, lowered))

        if hits == 0:
            return 0.0

        if has_otp_like and has_money_like:
            return 0.92

        score = (hits * 0.18)
        if any(word in lowered for word in ["urgent", "तुरंत", "अभी"]):
            score += 0.1
        return _clamp01(score)

    def _scan_sarvam(self, text: str) -> float:
        body = json.dumps(
            {
                "text": text,
                "language": "hi-IN",
                "task": "scam_intent_risk",
            }
        ).encode("utf-8")

        req = request.Request(
            SARVAM_ENDPOINT,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {SARVAM_API_KEY}",
                "x-api-key": SARVAM_API_KEY,
            },
        )
        with request.urlopen(req, timeout=SARVAM_TIMEOUT_SEC) as resp:
            content = resp.read().decode("utf-8")
        payload = json.loads(content)
        score = _find_numeric_score(payload)
        if score is None:
            raise ValueError("No numeric risk score in Sarvam response")
        return _clamp01(score)

    def scan(self, transcript: str) -> tuple[float, str]:
        text = transcript.strip()
        if not text:
            return 0.0, "none"

        fallback_score = self._fallback_score(text)

        if self.enabled:
            try:
                sarvam_score = self._scan_sarvam(text)
                if fallback_score > sarvam_score:
                    return fallback_score, "rules+sarvam"
                return sarvam_score, "sarvam"
            except Exception:
                pass

        return fallback_score, "fallback"

    def fusion(self, voice_score: float, intent_score: float) -> float:
        voice_weight = max(0.0, float(VOICE_FUSION_WEIGHT))
        intent_weight = max(0.0, float(INTENT_FUSION_WEIGHT))
        total = voice_weight + intent_weight
        if total <= 0:
            return _clamp01((voice_score + intent_score) / 2.0)
        return _clamp01(
            (voice_score * (voice_weight / total))
            + (intent_score * (intent_weight / total))
        )
