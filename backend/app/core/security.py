"""
A.E.G.I.S Security, Token & Authentication Utilities
"""
import hashlib
import hmac
import logging
import secrets
import smtplib
import ssl
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from typing import Any, Optional

import jwt
from fastapi import Header, HTTPException, status

from .config import (
    ACCESS_TOKEN_TTL_SEC,
    DEV_EXPOSE_OTP,
    JWT_ALGORITHM,
    JWT_SECRET,
    OTP_EXPIRY_SEC,
    OTP_FROM_EMAIL,
    OTP_LENGTH,
    OTP_PEPPER,
    OTP_RATE_LIMIT,
    REFRESH_SECRET,
    REFRESH_TOKEN_TTL_SEC,
    SMTP_HOST,
    SMTP_PASS,
    SMTP_PORT,
    SMTP_USER,
)
from .db import get_db

logger = logging.getLogger(__name__)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def hash_password(password: str) -> str:
    """Hash password using PBKDF2-HMAC-SHA256 with random salt."""
    salt = secrets.token_hex(16)
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100_000)
    return f"{salt}${key.hex()}"


def verify_password(password: str, hashed_value: str) -> bool:
    """Verify password against stored salt and PBKDF2 hash."""
    if not hashed_value or "$" not in hashed_value:
        return False
    salt, expected_hex = hashed_value.split("$", 1)
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100_000)
    return hmac.compare_digest(key.hex(), expected_hex)


def access_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "type": "access",
        "iat": int(now_utc().timestamp()),
        "exp": int((now_utc() + timedelta(seconds=ACCESS_TOKEN_TTL_SEC)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def refresh_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "jti": secrets.token_hex(16),
        "iat": int(now_utc().timestamp()),
        "exp": int((now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).timestamp()),
    }
    return jwt.encode(payload, REFRESH_SECRET, algorithm=JWT_ALGORITHM)


def pending_token(user_id: int, flow: str) -> str:
    payload = {
        "sub": str(user_id),
        "flow": flow,
        "type": "pending",
        "iat": int(now_utc().timestamp()),
        "exp": int((now_utc() + timedelta(seconds=OTP_EXPIRY_SEC)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str, secret: str = JWT_SECRET) -> dict[str, Any]:
    try:
        return jwt.decode(token, secret, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired."
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or malformed token."
        )


def refresh_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def make_otp() -> str:
    """Generate cryptographically secure numeric OTP."""
    digits = [str(secrets.randbelow(10)) for _ in range(OTP_LENGTH)]
    return "".join(digits)


def hash_otp(code: str) -> str:
    raw = f"{OTP_PEPPER}:{code.strip()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def mask_email(email: str) -> str:
    if "@" not in email:
        return email
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        return f"{local[:1]}*@{domain}"
    return f"{local[:2]}***{local[-1:]}@{domain}"


def mask_phone(phone: str) -> str:
    cleaned = phone.strip()
    if len(cleaned) <= 4:
        return cleaned
    return f"{'*' * (len(cleaned) - 4)}{cleaned[-4:]}"


def rate_limit_email(email: str) -> bool:
    """Check if OTP challenges exceed rate limit within expiry window."""
    with get_db() as conn:
        cursor = conn.cursor()
        window_start = (now_utc() - timedelta(seconds=OTP_EXPIRY_SEC)).isoformat()
        row = cursor.execute(
            """
            SELECT COUNT(*) AS total
            FROM otp_challenges
            WHERE destination = ? AND created_at >= ?
            """,
            (email.lower(), window_start),
        ).fetchone()
        return int(row["total"]) < OTP_RATE_LIMIT


def send_email_otp(recipient: str, code: str, reason: str = "login verification") -> tuple[bool, str]:
    """Send OTP code via SMTP. If unconfigured or in DEV mode, provide graceful fallback."""
    if not SMTP_HOST or not SMTP_USER or not SMTP_PASS:
        logger.warning(f"SMTP not configured. OTP for {recipient} was not dispatched via email.")
        return True, "simulated_dispatch"

    message = EmailMessage()
    message["Subject"] = f"A.E.G.I.S Security Code: {code}"
    message["From"] = OTP_FROM_EMAIL
    message["To"] = recipient
    message.set_content(
        f"Hello,\n\n"
        f"Your A.E.G.I.S verification code for {reason} is:\n\n"
        f"  {code}\n\n"
        f"This code will expire in {OTP_EXPIRY_SEC // 60} minutes.\n"
        f"If you did not request this code, please secure your account immediately.\n\n"
        f"Team A.E.G.I.S"
    )

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.starttls(context=context)
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(message)
        return True, "email_dispatched"
    except Exception as exc:
        logger.error(f"Failed to dispatch OTP email to {recipient}: {exc}")
        return False, str(exc)


def auth_user(authorization: Optional[str] = Header(None)) -> dict[str, Any]:
    """FastAPI Header Dependency to extract and validate authenticated user."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header."
        )

    token = authorization.split(" ", 1)[1].strip()
    payload = decode_token(token, secret=JWT_SECRET)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is not a valid access token."
        )

    user_id = payload.get("sub")
    with get_db() as conn:
        cursor = conn.cursor()
        user = cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account not found."
            )
        return dict(user)


def auth_success_payload(user: dict[str, Any], access_tok: str, refresh_tok: str) -> dict[str, Any]:
    return {
        "status": "success",
        "requires_2fa": False,
        "token": access_tok,
        "refresh_token": refresh_tok,
        "user": {
            "id": user["id"],
            "full_name": user["full_name"],
            "email": user["email"],
            "phone": user["phone"],
            "two_fa_enabled": bool(user["two_fa_enabled"]),
            "auto_delete_logs": bool(user["auto_delete_logs"]),
            "created_at": user["created_at"],
        },
    }
