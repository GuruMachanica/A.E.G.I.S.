import base64
import hashlib
import hmac
import secrets
import sqlite3
import string
import time
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from typing import Any, Optional

import jwt
from fastapi import HTTPException

from .config import (
    ACCESS_TOKEN_TTL_SEC,
    JWT_SECRET,
    OTP_EXPIRY_SEC,
    OTP_FROM_EMAIL,
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


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.isoformat()


def make_otp() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(6))


def hash_otp(otp: str) -> str:
    return hashlib.sha256(f"{otp}:{OTP_PEPPER}".encode()).hexdigest()


def hash_password(password: str, salt: Optional[str] = None) -> str:
    resolved_salt = (
        salt
        or base64.urlsafe_b64encode(secrets.token_bytes(16)).decode()
    )
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), resolved_salt.encode(), 120000
    )
    return f"{resolved_salt}${base64.urlsafe_b64encode(digest).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt, expected = stored.split("$", 1)
    except ValueError:
        return False
    check = hash_password(password, salt).split("$", 1)[1]
    return hmac.compare_digest(check, expected)


def encode_token(secret: str, payload: dict[str, Any], ttl_sec: int) -> str:
    exp = int(time.time()) + ttl_sec
    p = {**payload, "exp": exp}
    return jwt.encode(p, secret, algorithm="HS256")


def decode_token(secret: str, token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, secret, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid token.") from exc


def access_token(user_id: int) -> str:
    return encode_token(
        JWT_SECRET,
        {"sub": str(user_id), "type": "access"},
        ACCESS_TOKEN_TTL_SEC,
    )


def pending_token(user_id: int) -> str:
    return encode_token(
        JWT_SECRET,
        {"sub": str(user_id), "type": "pending"},
        600,
    )


def refresh_token(user_id: int) -> str:
    return encode_token(
        REFRESH_SECRET,
        {"sub": str(user_id), "type": "refresh", "jti": secrets.token_hex(12)},
        REFRESH_TOKEN_TTL_SEC,
    )


def refresh_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def mask_email(email: str) -> str:
    if "@" not in email:
        return "***"
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        return f"{local[0]}***@{domain}" if local else f"***@{domain}"
    return f"{local[0]}***{local[-1]}@{domain}"


def rate_limit_email(destination: str) -> None:
    conn = get_db()
    cursor = conn.cursor()
    cutoff = iso(now_utc() - timedelta(minutes=10))
    row = cursor.execute(
        """
        SELECT COUNT(*) AS n
        FROM otp_challenges
        WHERE destination = ? AND created_at >= ?
        """,
        (destination, cutoff),
    ).fetchone()
    conn.close()
    if row and int(row["n"]) >= OTP_RATE_LIMIT:
        raise HTTPException(status_code=429, detail="OTP rate limit exceeded.")


def send_email_otp(destination: str, otp: str, purpose: str) -> None:
    if not SMTP_HOST or not SMTP_USER or not SMTP_PASS:
        print(f"[DEV OTP] {purpose} -> {destination}: {otp}")
        return

    import smtplib

    msg = EmailMessage()
    msg["Subject"] = "Your A.E.G.I.S. verification code"
    msg["From"] = OTP_FROM_EMAIL
    msg["To"] = destination
    expiry_minutes = OTP_EXPIRY_SEC // 60
    msg.set_content(
        f"Your OTP is: {otp}\n\n"
        f"It expires in {expiry_minutes} minutes.\n"
        f"Purpose: {purpose}."
    )
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
            smtp.starttls()
            smtp.login(SMTP_USER, SMTP_PASS)
            smtp.send_message(msg)
    except smtplib.SMTPAuthenticationError as exc:
        raise HTTPException(
            status_code=502,
            detail="SMTP authentication failed. Use App Password for Gmail.",
        ) from exc
    except smtplib.SMTPException as exc:
        raise HTTPException(
            status_code=502,
            detail=f"SMTP error: {exc}",
        ) from exc


def auth_user(authorization: Optional[str]) -> sqlite3.Row:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    token = authorization.split(" ", 1)[1]
    payload = decode_token(JWT_SECRET, token)
    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type.")

    user_id = int(payload["sub"])
    conn = get_db()
    row = conn.execute(
        "SELECT * FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=401, detail="User not found.")
    return row


def auth_success_payload(
    user: sqlite3.Row,
    token: str,
    refresh_token_value: str,
) -> dict[str, Any]:
    return {
        "token": token,
        "refresh_token": refresh_token_value,
        "expires_in": ACCESS_TOKEN_TTL_SEC,
        "user_id": str(user["id"]),
        "full_name": user["full_name"],
        "email": user["email"],
        "phone": user["phone"],
    }
