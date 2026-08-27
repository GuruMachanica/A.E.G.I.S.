from app.services.risk_engine import RiskEngine, SCAM_ALERT_RULES, HIGH_RISK_PATTERNS


class IntentRiskScanner:
    def __init__(self) -> None:
        self.engine = RiskEngine()

    def scan(self, text: str) -> float:
        return RiskEngine.calculate_intent_risk(text)


__all__ = ["IntentRiskScanner", "RiskEngine", "SCAM_ALERT_RULES", "HIGH_RISK_PATTERNS"]
