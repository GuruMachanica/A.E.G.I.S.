"""
Phone Number Reputation & Threat Intelligence Lookup Service
"""
import re
from typing import Any

# Known suspicious area codes, premium rate prefixes, and scam carrier ranges
SUSPICIOUS_PREFIXES = {
    "+1876": "Caribbean Sweepstakes Scam Area Code",
    "+1284": "BVI Premium Rate Callback Trap",
    "+1473": "Grenada One-Ring Scam Area Code",
    "+1809": "Dominican Republic One-Ring Scam",
    "+232": "Sierra Leone International Robocall Range",
    "+252": "Somalia One-Ring Callback Range",
    "+92": "Cross-Border Social Engineering Call Range",
}

SUSPICIOUS_NUMBER_PATTERNS = [
    r"^\+91(?:140|141)\d{7}$",  # Unregistered Indian Telemarketing Ranges
    r"^\+?00\d+$",              # Double Zero International Spoofing
    r"^\+?[0-9]{1,4}1900\d+$",  # Premium Rate Toll Trap
]


class PhoneLookupService:
    @staticmethod
    def analyze_number(phone_number: str) -> dict[str, Any]:
        """Evaluate phone number risk, carrier region, and spam indicators."""
        cleaned = re.sub(r"[^\d+]", "", phone_number.strip())
        if not cleaned:
            return {
                "phone_number": phone_number,
                "valid": False,
                "spam_score": 0.0,
                "risk_level": "UNKNOWN",
                "tags": ["invalid_format"],
                "warning": "Phone number is empty or invalid format.",
            }

        tags: list[str] = []
        warning = None
        spam_score = 0.0

        # Check prefix blacklist
        for prefix, desc in SUSPICIOUS_PREFIXES.items():
            if cleaned.startswith(prefix):
                tags.append("high_risk_country_code")
                tags.append("one_ring_callback_risk")
                warning = f"High Risk Prefix: {desc}"
                spam_score = max(spam_score, 0.85)
                break

        # Check regex patterns
        for pattern in SUSPICIOUS_NUMBER_PATTERNS:
            if re.match(pattern, cleaned):
                tags.append("telemarketer_or_spoof_pattern")
                warning = warning or "Suspicious caller ID pattern flagged by threat engine."
                spam_score = max(spam_score, 0.75)
                break

        # Check shortcodes or invalid lengths
        digits_only = re.sub(r"\D", "", cleaned)
        if len(digits_only) < 7 or len(digits_only) > 15:
            tags.append("abnormal_length")
            spam_score = max(spam_score, 0.50)

        if spam_score >= 0.70:
            risk_level = "DANGER"
        elif spam_score >= 0.35:
            risk_level = "WARNING"
        else:
            risk_level = "SAFE"
            tags.append("clean_reputation")

        return {
            "phone_number": cleaned,
            "valid": True,
            "spam_score": round(spam_score, 2),
            "risk_level": risk_level,
            "tags": tags,
            "warning": warning,
        }


# Global singleton service
phone_lookup_service = PhoneLookupService()
