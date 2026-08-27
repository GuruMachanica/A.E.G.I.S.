"""
Unit tests for Risk Engine & NLP Threat Classifier
"""
from app.services.risk_engine import RiskEngine


def test_keyword_extraction_otp():
    text = "Hello sir, please provide your OTP and bank account number right now."
    keywords, alerts, primary_alert = RiskEngine.extract_keywords_and_alerts(text)

    assert "otp" in keywords
    assert "bank account" in keywords
    assert primary_alert is not None
    assert "OTP" in primary_alert or "ALERT" in primary_alert


def test_intent_risk_scoring():
    safe_text = "Hi mom, I am coming home for dinner at 7 PM."
    assert RiskEngine.calculate_intent_risk(safe_text) == 0.0

    threat_text = "Your bank account is blocked. Send money immediately to avoid arrest. Tell OTP."
    threat_score = RiskEngine.calculate_intent_risk(threat_text)
    assert threat_score >= 0.85


def test_hybrid_risk_fusion():
    # Low voice risk, high scam intent
    result = RiskEngine.compute_hybrid_risk(voice_score=0.1, intent_score=0.9)
    assert result["overall_score"] > 0.4
    assert result["alert_level"] in ("WARNING", "DANGER")

    # High voice risk (deepfake)
    result_fake = RiskEngine.compute_hybrid_risk(voice_score=0.85, intent_score=0.0)
    assert result_fake["alert_level"] in ("WARNING", "DANGER")
