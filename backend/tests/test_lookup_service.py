"""
Unit tests for Phone Lookup & Reputation Service
"""
from app.services.lookup_service import phone_lookup_service


def test_analyze_valid_clean_number():
    res = phone_lookup_service.analyze_number("+14155552671")
    assert res["valid"] is True
    assert res["risk_level"] == "SAFE"
    assert res["spam_score"] == 0.0
    assert "clean_reputation" in res["tags"]


def test_analyze_suspicious_prefix():
    # Area code +1876 is known Caribbean lottery scam prefix
    res = phone_lookup_service.analyze_number("+18765551234")
    assert res["valid"] is True
    assert res["risk_level"] == "DANGER"
    assert res["spam_score"] >= 0.80
    assert "high_risk_country_code" in res["tags"]


def test_analyze_telemarketer_pattern():
    res = phone_lookup_service.analyze_number("+911401234567")
    assert res["valid"] is True
    assert res["risk_level"] == "DANGER"
    assert "telemarketer_or_spoof_pattern" in res["tags"]


def test_analyze_empty_number():
    res = phone_lookup_service.analyze_number("")
    assert res["valid"] is False
    assert res["risk_level"] == "UNKNOWN"
