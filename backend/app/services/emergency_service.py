"""
Guardian Emergency Alert Service
Dispatches SOS threat notifications to designated emergency contacts upon high-risk detection.
"""
import logging
from typing import Any, Optional
from datetime import datetime, timezone

from app.core.security import send_email_otp

logger = logging.getLogger(__name__)


class EmergencyAlertService:
    @staticmethod
    def dispatch_threat_alert(
        guardian_email: str,
        user_name: str,
        caller_number: str,
        risk_score: float,
        detected_keywords: list[str],
        risk_level: str = "DANGER",
    ) -> dict[str, Any]:
        """Dispatch high-priority SOS alert email to emergency guardian."""
        if not guardian_email or "@" not in guardian_email:
            return {"status": "skipped", "reason": "Invalid or missing guardian email"}

        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        keywords_str = ", ".join(detected_keywords) if detected_keywords else "Deepfake synthetic voice detected"
        
        reason = (
            f"URGENT FRAUD ALERT for {user_name}!\n\n"
            f"A.E.G.I.S detected a HIGH-RISK fraudulent call in progress.\n"
            f"• Caller Number: {caller_number}\n"
            f"• Threat Level: {risk_level} ({risk_score * 100:.1f}% risk score)\n"
            f"• Flagged Patterns: {keywords_str}\n"
            f"• Detection Timestamp: {timestamp}\n\n"
            f"ACTION REQUIRED:\n"
            f"Please reach out to {user_name} immediately to ensure they do NOT transfer money, "
            f"share bank passwords, or disclose OTP codes."
        )

        success, msg = send_email_otp(
            recipient=guardian_email,
            code="CRITICAL-FRAUD-ALERT",
            reason=reason,
        )

        return {
            "status": "dispatched" if success else "failed",
            "guardian_email": guardian_email,
            "timestamp": timestamp,
            "detail": msg,
        }


emergency_service = EmergencyAlertService()
