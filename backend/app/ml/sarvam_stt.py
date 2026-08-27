from app.services.stt_service import stt_service, SarvamSTTService
from app.services.risk_engine import RiskEngine

sarvam_stt = stt_service.transcribe_pcm
classify_scam_alert = RiskEngine.extract_keywords_and_alerts

__all__ = ["stt_service", "SarvamSTTService", "sarvam_stt", "classify_scam_alert"]
