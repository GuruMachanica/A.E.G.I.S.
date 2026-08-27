"""
Unit tests for Guardian Emergency SOS Alert Service
"""
from app.services.emergency_service import emergency_service


def test_emergency_alert_dispatch_skipped_invalid_email():
    res = emergency_service.dispatch_threat_alert(
        guardian_email="",
        user_name="Test User",
        caller_number="+1234567890",
        risk_score=0.92,
        detected_keywords=["otp", "bank transfer"],
    )
    assert res["status"] == "skipped"


def test_emergency_alert_dispatch_valid_payload():
    res = emergency_service.dispatch_threat_alert(
        guardian_email="guardian@example.com",
        user_name="John Doe",
        caller_number="+18765551234",
        risk_score=0.95,
        detected_keywords=["digital arrest", "police", "aadhaar"],
        risk_level="DANGER",
    )
    assert res["status"] in ["dispatched", "failed"]
    assert res["guardian_email"] == "guardian@example.com"
