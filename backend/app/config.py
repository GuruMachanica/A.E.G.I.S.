import os
from pathlib import Path


def load_env_file() -> None:
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        key, value = s.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_env_file()


def _bool_env(name: str, default: str = "false") -> bool:
    value = os.getenv(name, default)
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _str_env(name: str, default: str = "") -> str:
    return str(os.getenv(name, default)).strip().strip('"').strip("'")


SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
OTP_FROM_EMAIL = os.getenv("OTP_FROM_EMAIL", "no-reply@aegis.local")
OTP_EXPIRY_SEC = int(os.getenv("OTP_EXPIRY_SEC", "300"))
OTP_RATE_LIMIT = int(os.getenv("OTP_RATE_LIMIT", "5"))
JWT_SECRET = os.getenv("JWT_SECRET", "dev-jwt-secret")
REFRESH_SECRET = os.getenv("REFRESH_SECRET", "dev-refresh-secret")
OTP_PEPPER = os.getenv("OTP_PEPPER", "dev-otp-pepper")
ACCESS_TOKEN_TTL_SEC = int(os.getenv("ACCESS_TOKEN_TTL_SEC", "3600"))
REFRESH_TOKEN_TTL_SEC = int(os.getenv("REFRESH_TOKEN_TTL_SEC", "2592000"))
DB_PATH = os.getenv(
    "DATABASE_PATH",
    str((Path(__file__).resolve().parent.parent / "aegis_backend.db")),
)
CORS_ALLOW_ORIGINS = os.getenv("CORS_ALLOW_ORIGINS", "*")
VOICE_MODEL_PATH = os.getenv("VOICE_MODEL_PATH", "")
INTENT_MODEL_PATH = os.getenv("INTENT_MODEL_PATH", "")
ASSIST_FAKEVOICE_DIR = os.getenv("ASSIST_FAKEVOICE_DIR", "")
ASSIST_TARGET_SAMPLE_RATE = int(
    os.getenv("ASSIST_TARGET_SAMPLE_RATE", "16000")
)

SARVAM_API_KEY = (
    _str_env("SARVAM_API_KEY")
    or _str_env("SARVAM_STT_API_KEY")
    or _str_env("AEGIS_SARVAM_API_KEY")
)
SARVAM_ENDPOINT = _str_env("SARVAM_ENDPOINT", "https://api.sarvam.ai/v1")
SARVAM_STT_ENDPOINT = os.getenv(
    "SARVAM_STT_ENDPOINT", "https://api.sarvam.ai/speech-to-text"
)
_sarvam_enabled_raw = _str_env("SARVAM_ENABLED", "")
if _sarvam_enabled_raw:
    SARVAM_ENABLED = _bool_env("SARVAM_ENABLED", "false")
else:
    SARVAM_ENABLED = bool(SARVAM_API_KEY and SARVAM_ENDPOINT)
SARVAM_TIMEOUT_SEC = int(os.getenv("SARVAM_TIMEOUT_SEC", "6"))
VOICE_FUSION_WEIGHT = float(os.getenv("VOICE_FUSION_WEIGHT", "0.55"))
INTENT_FUSION_WEIGHT = float(os.getenv("INTENT_FUSION_WEIGHT", "0.45"))
INTENT_SCAN_DEBOUNCE_SEC = float(
    os.getenv("INTENT_SCAN_DEBOUNCE_SEC", "1.0")
)
