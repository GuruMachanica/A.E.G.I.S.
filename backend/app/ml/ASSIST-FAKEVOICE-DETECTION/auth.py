import hashlib
import os
import secrets
import smtplib
import sqlite3
import ssl
import time
import uuid
from email.message import EmailMessage
from typing import Any, Optional

import jwt
from fastapi import APIRouter, Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

try:
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token
except Exception:
    google_requests = None
    google_id_token = None


router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)

BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data")
AUTH_DB_PATH = os.path.join(DATA_DIR, "auth.db")

JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_ISSUER = os.getenv("JWT_ISSUER", "aegis-backend")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))
OTP_EXPIRE_MINUTES = int(os.getenv("OTP_EXPIRE_MINUTES", "10"))
OTP_LENGTH = int(os.getenv("OTP_LENGTH", "6"))
ALLOW_INSECURE_GOOGLE_TOKEN = os.getenv("ALLOW_INSECURE_GOOGLE_TOKEN", "false").lower() == "true"
DEV_EXPOSE_OTP = os.getenv("DEV_EXPOSE_OTP", "false").lower() == "true"


class GoogleLoginRequest(BaseModel):
    idToken: str = Field(min_length=10)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class TwoFAStartResponse(BaseModel):
    message: str
    delivery: str
    expires_in_seconds: int
    otp_dev_only: Optional[str] = None


class TwoFAVerifyRequest(BaseModel):
    code: str = Field(min_length=4, max_length=12)


class UserResponse(BaseModel):
    id: int
    email: str
    name: Optional[str] = None


class AuthTokensResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


def init_auth_db() -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    conn = sqlite3.connect(AUTH_DB_PATH)
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL UNIQUE,
                name TEXT,
                google_sub TEXT UNIQUE,
                created_at INTEGER NOT NULL,
                last_login_at INTEGER NOT NULL
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS refresh_tokens (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                token_hash TEXT NOT NULL UNIQUE,
                expires_at INTEGER NOT NULL,
                revoked INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS otp_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                code_hash TEXT NOT NULL,
                expires_at INTEGER NOT NULL,
                consumed INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
            """
        )
        conn.commit()
    finally:
        conn.close()


def get_db_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(AUTH_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _now_ts() -> int:
    return int(time.time())


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _get_google_client_ids() -> list[str]:
    candidates: list[str] = []
    client_id = os.getenv("GOOGLE_CLIENT_ID", "").strip()
    if client_id:
        candidates.append(client_id)
    many = os.getenv("GOOGLE_CLIENT_IDS", "").strip()
    if many:
        candidates.extend([item.strip() for item in many.split(",") if item.strip()])
    # Preserve order while removing duplicates
    seen: set[str] = set()
    unique: list[str] = []
    for value in candidates:
        if value not in seen:
            unique.append(value)
            seen.add(value)
    return unique


def verify_google_token(raw_id_token: str) -> dict[str, Any]:
    if ALLOW_INSECURE_GOOGLE_TOKEN and raw_id_token.startswith("dev:"):
        parts = raw_id_token.split(":", maxsplit=2)
        if len(parts) < 2 or not parts[1].strip():
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid dev token")
        email = parts[1].strip()
        name = parts[2].strip() if len(parts) > 2 and parts[2].strip() else email.split("@")[0]
        return {
            "email": email,
            "email_verified": True,
            "name": name,
            "sub": f"dev-{_sha256(email)[:16]}",
        }

    if google_id_token is None or google_requests is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google auth libraries are missing. Install google-auth.",
        )

    client_ids = _get_google_client_ids()
    if not client_ids:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GOOGLE_CLIENT_ID (or GOOGLE_CLIENT_IDS) is not configured.",
        )

    last_err: Optional[Exception] = None
    id_info: Optional[dict[str, Any]] = None
    request = google_requests.Request()
    for audience in client_ids:
        try:
            id_info = google_id_token.verify_oauth2_token(raw_id_token, request, audience)
            break
        except Exception as err:
            last_err = err

    if id_info is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google token: {last_err}",
        )

    if not id_info.get("email"):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Google token missing email")
    if id_info.get("email_verified") is False:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Google email not verified")

    return id_info


def upsert_google_user(email: str, name: Optional[str], google_sub: Optional[str]) -> dict[str, Any]:
    conn = get_db_connection()
    try:
        now = _now_ts()
        existing = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        if existing:
            conn.execute(
                """
                UPDATE users
                SET name = ?, google_sub = COALESCE(google_sub, ?), last_login_at = ?
                WHERE id = ?
                """,
                (name or existing["name"], google_sub, now, existing["id"]),
            )
            conn.commit()
            updated = conn.execute("SELECT * FROM users WHERE id = ?", (existing["id"],)).fetchone()
            return dict(updated)

        conn.execute(
            """
            INSERT INTO users (email, name, google_sub, created_at, last_login_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (email, name, google_sub, now, now),
        )
        conn.commit()
        created = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        return dict(created)
    finally:
        conn.close()


def _create_jwt_token(user: dict[str, Any], token_type: str, expires_in_seconds: int) -> str:
    now = _now_ts()
    payload = {
        "sub": str(user["id"]),
        "email": user["email"],
        "name": user.get("name"),
        "typ": token_type,
        "jti": uuid.uuid4().hex,
        "iat": now,
        "exp": now + expires_in_seconds,
        "iss": JWT_ISSUER,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _store_refresh_token(user_id: int, refresh_token: str, expires_at: int) -> None:
    conn = get_db_connection()
    try:
        conn.execute(
            """
            INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, revoked, created_at)
            VALUES (?, ?, ?, ?, 0, ?)
            """,
            (uuid.uuid4().hex, user_id, _sha256(refresh_token), expires_at, _now_ts()),
        )
        conn.commit()
    finally:
        conn.close()


def create_auth_tokens(user: dict[str, Any]) -> AuthTokensResponse:
    access_expires_seconds = ACCESS_TOKEN_EXPIRE_MINUTES * 60
    refresh_expires_seconds = REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60

    access_token = _create_jwt_token(user, token_type="access", expires_in_seconds=access_expires_seconds)
    refresh_token = _create_jwt_token(user, token_type="refresh", expires_in_seconds=refresh_expires_seconds)
    _store_refresh_token(user_id=user["id"], refresh_token=refresh_token, expires_at=_now_ts() + refresh_expires_seconds)

    return AuthTokensResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=access_expires_seconds,
        user=UserResponse(id=user["id"], email=user["email"], name=user.get("name")),
    )


def _decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM], issuer=JWT_ISSUER)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def _find_user_by_id(user_id: int) -> Optional[dict[str, Any]]:
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict[str, Any]:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authorization required")

    payload = _decode_token(credentials.credentials)
    if payload.get("typ") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Access token required")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing subject")

    user = _find_user_by_id(int(user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def _send_email_otp(email_to: str, code: str) -> bool:
    smtp_host = os.getenv("SMTP_HOST", "").strip()
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "").strip()
    smtp_password = os.getenv("SMTP_PASSWORD", "").strip()
    smtp_sender = os.getenv("SMTP_SENDER", smtp_user).strip()

    if not smtp_host or not smtp_user or not smtp_password or not smtp_sender:
        return False

    message = EmailMessage()
    message["Subject"] = "Your AEGIS verification code"
    message["From"] = smtp_sender
    message["To"] = email_to
    message.set_content(f"Your verification code is: {code}\nThis code expires in {OTP_EXPIRE_MINUTES} minutes.")

    context = ssl.create_default_context()
    with smtplib.SMTP(smtp_host, smtp_port, timeout=20) as server:
        server.starttls(context=context)
        server.login(smtp_user, smtp_password)
        server.send_message(message)
    return True


def _create_and_store_otp(user_id: int) -> str:
    code = "".join(secrets.choice("0123456789") for _ in range(OTP_LENGTH))
    code_hash = _sha256(code)
    now = _now_ts()
    expires_at = now + OTP_EXPIRE_MINUTES * 60

    conn = get_db_connection()
    try:
        conn.execute("UPDATE otp_codes SET consumed = 1 WHERE user_id = ? AND consumed = 0", (user_id,))
        conn.execute(
            """
            INSERT INTO otp_codes (user_id, code_hash, expires_at, consumed, created_at)
            VALUES (?, ?, ?, 0, ?)
            """,
            (user_id, code_hash, expires_at, now),
        )
        conn.commit()
    finally:
        conn.close()
    return code


@router.post("/google-login", response_model=AuthTokensResponse)
def google_login(payload: GoogleLoginRequest) -> AuthTokensResponse:
    id_info = verify_google_token(payload.idToken)
    user = upsert_google_user(
        email=id_info["email"].strip().lower(),
        name=id_info.get("name"),
        google_sub=id_info.get("sub"),
    )
    return create_auth_tokens(user)


@router.post("/refresh", response_model=AuthTokensResponse)
def refresh_token(payload: RefreshTokenRequest) -> AuthTokensResponse:
    raw_token = payload.refresh_token
    decoded = _decode_token(raw_token)
    if decoded.get("typ") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token required")

    conn = get_db_connection()
    try:
        token_row = conn.execute(
            "SELECT * FROM refresh_tokens WHERE token_hash = ? AND revoked = 0",
            (_sha256(raw_token),),
        ).fetchone()
        if not token_row:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token revoked or unknown")
        if int(token_row["expires_at"]) <= _now_ts():
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired")

        user = conn.execute("SELECT * FROM users WHERE id = ?", (token_row["user_id"],)).fetchone()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

        conn.execute("UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?", (_sha256(raw_token),))
        conn.commit()
        return create_auth_tokens(dict(user))
    finally:
        conn.close()


@router.get("/me", response_model=UserResponse)
def who_am_i(current_user: dict[str, Any] = Depends(get_current_user)) -> UserResponse:
    return UserResponse(id=current_user["id"], email=current_user["email"], name=current_user.get("name"))


@router.post("/2fa/start", response_model=TwoFAStartResponse)
def start_two_fa(current_user: dict[str, Any] = Depends(get_current_user)) -> TwoFAStartResponse:
    code = _create_and_store_otp(current_user["id"])
    sent = _send_email_otp(current_user["email"], code)

    message = "OTP sent" if sent else "OTP generated"
    delivery = "email" if sent else "logged"

    # Fallback for environments without SMTP: log OTP in backend console for dev/testing.
    if not sent:
        print(f"[2FA] OTP for {current_user['email']}: {code}")

    return TwoFAStartResponse(
        message=message,
        delivery=delivery,
        expires_in_seconds=OTP_EXPIRE_MINUTES * 60,
        otp_dev_only=code if DEV_EXPOSE_OTP else None,
    )


@router.post("/2fa/verify")
def verify_two_fa(payload: TwoFAVerifyRequest, current_user: dict[str, Any] = Depends(get_current_user)) -> dict[str, str]:
    code_hash = _sha256(payload.code)
    now = _now_ts()

    conn = get_db_connection()
    try:
        row = conn.execute(
            """
            SELECT *
            FROM otp_codes
            WHERE user_id = ? AND code_hash = ? AND consumed = 0
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (current_user["id"], code_hash),
        ).fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")
        if int(row["expires_at"]) <= now:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP expired")

        conn.execute("UPDATE otp_codes SET consumed = 1 WHERE id = ?", (row["id"],))
        conn.commit()
        return {"message": "2FA verified"}
    finally:
        conn.close()


def register_auth(app: FastAPI) -> None:
    init_auth_db()
    app.include_router(router)
