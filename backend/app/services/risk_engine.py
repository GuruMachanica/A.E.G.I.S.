"""
Risk Engine: NLP Keyword Scanner, Scam Classifier & Hybrid Fusion Engine
"""
import re
from typing import Optional

from app.core.config import VOICE_FUSION_WEIGHT, INTENT_FUSION_WEIGHT

# Comprehensive Threat Keyword Patterns (English & Hindi/Hinglish)
SCAM_ALERT_RULES: list[tuple[str, str, str]] = [
    ("otp", "otp_asked", "🚨 ALERT: Someone is asking for your OTP / verification code. NEVER share your OTP!"),
    ("verification code", "otp_asked", "🚨 ALERT: Someone is asking for your verification code. NEVER share it!"),
    ("pin", "otp_asked", "🚨 ALERT: Someone is asking for your PIN. NEVER share your PIN with anyone!"),
    ("password", "otp_asked", "🚨 ALERT: Asking for password. A.E.G.I.S advises you not to disclose passwords."),
    ("cvv", "otp_asked", "🚨 ALERT: CVV requested! Never disclose card CVV to callers."),
    ("upi pin", "otp_asked", "🚨 ALERT: UPI PIN requested! Entering your UPI PIN will DEDUCT money."),
    ("bank account", "bank_details", "⚠️ WARNING: Caller is requesting bank account details. Verify caller identity."),
    ("credit card", "bank_details", "⚠️ WARNING: Credit card details requested. Do not disclose numbers or expiry."),
    ("debit card", "bank_details", "⚠️ WARNING: Debit card details requested. Do not share card numbers."),
    ("kyc", "kyc_urgency", "⚠️ WARNING: KYC update pressure detected. Official banks do not update KYC via call."),
    ("account blocked", "account_threat", "🚨 ALERT: Account block threat detected. Banks do not threaten immediate freeze on phone."),
    ("arrest", "law_enforcement", "🚨 DANGER: Police / arrest threat (Digital Arrest scam). Hang up immediately."),
    ("lottery", "prize_scam", "⚠️ WARNING: Lottery or prize claim scam detected."),
    ("transfer money", "transfer_request", "🚨 DANGER: Urgent money transfer request detected."),
    ("send money", "transfer_request", "🚨 DANGER: Urgent money transfer request detected."),
    ("refund", "refund_scam", "⚠️ WARNING: Refund process request. Never send money to receive a refund."),
]

HIGH_RISK_PATTERNS = [
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
    r"urgent|immediately|right\s*now|तुरंत",
    r"\bmoney\b|पैसे|रुपये|रकम|rupaye",
    r"transfer\s*money|send\s*money|bhejo|bhjdo",
    r"reward\s*claim|lottery|jackpot",
    r"block\s*your\s*account|freeze\s*account|खाता\s*ब्लॉक",
    r"verification\s*code",
    r"upi\s*pin",
    r"arrest|police|cbi|customs|digital\s*arrest",
]


class RiskEngine:
    @staticmethod
    def extract_keywords_and_alerts(text: str) -> tuple[list[str], list[str], Optional[str]]:
        if not text:
            return [], [], None

        lowered = text.lower()
        detected_keywords: list[str] = []
        matched_alerts: list[str] = []
        primary_alert: Optional[str] = None

        for trigger, code, alert_msg in SCAM_ALERT_RULES:
            if trigger in lowered:
                detected_keywords.append(trigger)
                matched_alerts.append(alert_msg)
                if not primary_alert:
                    primary_alert = alert_msg

        return list(set(detected_keywords)), matched_alerts, primary_alert

    @classmethod
    def calculate_intent_risk(cls, text: str) -> float:
        if not text:
            return 0.0

        lowered = text.lower()
        hits = sum(1 for pattern in HIGH_RISK_PATTERNS if re.search(pattern, lowered))

        if hits == 0:
            return 0.0
        elif hits == 1:
            return 0.40
        elif hits == 2:
            return 0.70
        elif hits == 3:
            return 0.85
        else:
            return 0.95

    @classmethod
    def compute_hybrid_risk(
        cls,
        voice_score: float,
        intent_score: float,
        signal_quality: float = 1.0,
    ) -> dict[str, float | str]:
        """Fuse Deepfake synthetic voice score with NLP scam intent score."""
        voice_clamped = max(0.0, min(1.0, float(voice_score)))
        intent_clamped = max(0.0, min(1.0, float(intent_score)))

        overall = (voice_clamped * VOICE_FUSION_WEIGHT) + (intent_clamped * INTENT_FUSION_WEIGHT)
        overall = max(0.0, min(1.0, overall))

        if overall >= 0.65 or intent_clamped >= 0.80 or voice_clamped >= 0.80:
            label = "danger"
            alert_level = "DANGER"
        elif overall >= 0.35 or intent_clamped >= 0.40 or voice_clamped >= 0.40:
            label = "warning"
            alert_level = "WARNING"
        else:
            label = "safe"
            alert_level = "SAFE"

        return {
            "synthetic_voice_score": round(voice_clamped, 3),
            "scam_intent_score": round(intent_clamped, 3),
            "overall_score": round(overall, 3),
            "label": label,
            "alert_level": alert_level,
        }
