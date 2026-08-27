"""
A.E.G.I.S Backend Configuration Module
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Base paths
BASE_DIR = Path(__file__).resolve().parent.parent.parent
ENV_PATH = BASE_DIR / ".env"

if ENV_PATH.exists():
    load_dotenv(dotenv_path=ENV_PATH)
else:
    load_dotenv()

# --- Server & Network ---
API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
WS_URL = os.getenv("WS_URL", "ws://127.0.0.1:8000/assist/live-audio")
CORS_ALLOW_ORIGINS = os.getenv("CORS_ALLOW_ORIGINS", "*")

# --- Database ---
DATABASE_PATH = os.getenv("DATABASE_PATH", str(BASE_DIR / "aegis_backend.db"))

# --- JWT Authentication ---
JWT_SECRET = os.getenv("JWT_SECRET", "aegis-insecure-dev-secret-change-in-production-min32char")
REFRESH_SECRET = os.getenv("REFRESH_SECRET", "aegis-insecure-dev-refresh-secret-change-prod")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_TTL_SEC = int(os.getenv("ACCESS_TOKEN_TTL_SEC", "3600"))
REFRESH_TOKEN_TTL_SEC = int(os.getenv("REFRESH_TOKEN_TTL_SEC", "2592000"))

# --- OTP & 2FA ---
OTP_PEPPER = os.getenv("OTP_PEPPER", "aegis-otp-pepper-default")
OTP_EXPIRY_SEC = int(os.getenv("OTP_EXPIRY_SEC", "300"))
OTP_RATE_LIMIT = int(os.getenv("OTP_RATE_LIMIT", "5"))
OTP_LENGTH = int(os.getenv("OTP_LENGTH", "6"))
DEV_EXPOSE_OTP = os.getenv("DEV_EXPOSE_OTP", "false").lower() == "true"

# --- SMTP Email Delivery ---
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
OTP_FROM_EMAIL = os.getenv("OTP_FROM_EMAIL", "A.E.G.I.S Security <no-reply@aegis-security.local>")

# --- ML & Audio Processing ---
ASSIST_TARGET_SAMPLE_RATE = int(os.getenv("ASSIST_TARGET_SAMPLE_RATE", "16000"))
ASSIST_FAKEVOICE_DIR = os.getenv(
    "ASSIST_FAKEVOICE_DIR",
    str(BASE_DIR / "app" / "ml" / "ASSIST-FAKEVOICE-DETECTION")
)
VOICE_MODEL_PATH = os.getenv("VOICE_MODEL_PATH", "")
INTENT_MODEL_PATH = os.getenv("INTENT_MODEL_PATH", "")

# --- Sarvam STT & NLP Threat Intelligence ---
SARVAM_ENABLED = os.getenv("SARVAM_ENABLED", "true").lower() == "true"
SARVAM_ENDPOINT = os.getenv("SARVAM_ENDPOINT", "https://api.sarvam.ai/v1").rstrip("/")
SARVAM_STT_ENDPOINT = os.getenv("SARVAM_STT_ENDPOINT", "https://api.sarvam.ai/speech-to-text")
SARVAM_API_KEY = os.getenv("SARVAM_API_KEY", "")
SARVAM_TIMEOUT_SEC = int(os.getenv("SARVAM_TIMEOUT_SEC", "6"))

# --- Detection Weights & Thresholds ---
VOICE_FUSION_WEIGHT = float(os.getenv("VOICE_FUSION_WEIGHT", "0.55"))
INTENT_FUSION_WEIGHT = float(os.getenv("INTENT_FUSION_WEIGHT", "0.45"))
INTENT_SCAN_DEBOUNCE_SEC = float(os.getenv("INTENT_SCAN_DEBOUNCE_SEC", "1.5"))
