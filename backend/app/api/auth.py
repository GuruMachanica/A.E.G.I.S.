"""
Authentication & Profile API Endpoints
"""
import secrets
from datetime import timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.config import (
    DEV_EXPOSE_OTP,
    OTP_EXPIRY_SEC,
    REFRESH_SECRET,
    REFRESH_TOKEN_TTL_SEC,
    SMTP_HOST,
)
from app.core.db import get_db
from app.core.security import (
    access_token,
    auth_success_payload,
    auth_user,
    decode_token,
    hash_otp,
    hash_password,
    make_otp,
    mask_email,
    now_utc,
    pending_token,
    rate_limit_email,
    refresh_hash,
    refresh_token,
    send_email_otp,
    verify_password,
)
from app.schemas.auth import (
    GoogleLoginIn,
    LoginIn,
    PasswordUpdateIn,
    RefreshIn,
    RegisterIn,
    ResetRequestIn,
    SetPasswordIn,
    Start2FAIn,
    Verify2FAIn,
    VerifyLoginOtpIn,
)

router = APIRouter(tags=["auth"])


class ProfileUpdateIn(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    auto_delete_logs: Optional[bool] = None
    two_fa_enabled: Optional[bool] = None


@router.post("/auth/register")
def register(data: RegisterIn) -> dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        existing = cursor.execute(
            "SELECT id FROM users WHERE email = ? OR phone = ?",
            (data.email.lower(), data.phone.strip()),
        ).fetchone()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email or phone already exists.",
            )

        cursor.execute(
            """
            INSERT INTO users (full_name, email, phone, password_hash, two_fa_enabled, created_at)
            VALUES (?, ?, ?, ?, 0, ?)
            """,
            (
                data.full_name.strip(),
                data.email.lower(),
                data.phone.strip(),
                hash_password(data.password),
                now_utc().isoformat(),
            ),
        )
        user_id = cursor.lastrowid
        user = cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()

        acc_token = access_token(user_id)
        ref_token = refresh_token(user_id)
        cursor.execute(
            """
            INSERT INTO refresh_sessions (user_id, refresh_hash, device_id, created_at, expires_at, revoked)
            VALUES (?, ?, 'mobile', ?, ?, 0)
            """,
            (
                user_id,
                refresh_hash(ref_token),
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
            ),
        )

        return auth_success_payload(dict(user), acc_token, ref_token)


@router.post("/auth/login")
def login(data: LoginIn) -> dict[str, Any]:
    login_id = data.login.strip().lower()
    with get_db() as conn:
        cursor = conn.cursor()
        user = cursor.execute(
            "SELECT * FROM users WHERE email = ? OR phone = ?",
            (login_id, data.login.strip()),
        ).fetchone()

        if not user or not verify_password(data.password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email/phone or password.",
            )

        if user["two_fa_enabled"]:
            if not rate_limit_email(user["email"]):
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many OTP requests. Please wait a few minutes.",
                )

            otp = make_otp()
            pend_token = pending_token(user["id"], flow="login")
            cursor.execute(
                """
                INSERT INTO otp_challenges (user_id, channel, destination, otp_hash, pending_token, status, created_at, expires_at)
                VALUES (?, 'email', ?, ?, ?, 'pending', ?, ?)
                """,
                (
                    user["id"],
                    user["email"],
                    hash_otp(otp),
                    pend_token,
                    now_utc().isoformat(),
                    (now_utc() + timedelta(seconds=OTP_EXPIRY_SEC)).isoformat(),
                ),
            )
            send_email_otp(user["email"], otp, reason="account sign-in")

            payload = {
                "status": "requires_2fa",
                "requires_2fa": True,
                "pending_token": pend_token,
                "delivery": "email",
                "masked_destination": mask_email(user["email"]),
                "expires_in_seconds": OTP_EXPIRY_SEC,
            }
            if DEV_EXPOSE_OTP or not SMTP_HOST:
                payload["otp_dev_only"] = otp
            return payload

        acc_token = access_token(user["id"])
        ref_token = refresh_token(user["id"])
        cursor.execute(
            """
            INSERT INTO refresh_sessions (user_id, refresh_hash, device_id, created_at, expires_at, revoked)
            VALUES (?, ?, 'mobile', ?, ?, 0)
            """,
            (
                user["id"],
                refresh_hash(ref_token),
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
            ),
        )

        return auth_success_payload(dict(user), acc_token, ref_token)


@router.post("/auth/verify-login-otp")
@router.post("/auth/login/verify-otp")
def verify_login_otp(data: VerifyLoginOtpIn) -> dict[str, Any]:
    payload = decode_token(data.pending_token)
    if payload.get("type") != "pending" or payload.get("flow") != "login":
        raise HTTPException(status_code=400, detail="Invalid OTP verification token.")

    user_id = int(payload.get("sub"))
    with get_db() as conn:
        cursor = conn.cursor()
        challenge = cursor.execute(
            """
            SELECT * FROM otp_challenges
            WHERE user_id = ? AND pending_token = ? AND status = 'pending'
            ORDER BY id DESC LIMIT 1
            """,
            (user_id, data.pending_token),
        ).fetchone()

        if not challenge or challenge["expires_at"] < now_utc().isoformat():
            raise HTTPException(status_code=400, detail="OTP challenge expired or invalid.")

        if challenge["otp_hash"] != hash_otp(data.code):
            cursor.execute(
                "UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?",
                (challenge["id"],),
            )
            raise HTTPException(status_code=400, detail="Incorrect verification code.")

        cursor.execute("UPDATE otp_challenges SET status = 'consumed' WHERE id = ?", (challenge["id"],))
        user = cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()

        acc_token = access_token(user_id)
        ref_token = refresh_token(user_id)
        cursor.execute(
            """
            INSERT INTO refresh_sessions (user_id, refresh_hash, device_id, created_at, expires_at, revoked)
            VALUES (?, ?, 'mobile', ?, ?, 0)
            """,
            (
                user_id,
                refresh_hash(ref_token),
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
            ),
        )

        return auth_success_payload(dict(user), acc_token, ref_token)


@router.post("/auth/refresh")
def refresh(data: RefreshIn) -> dict[str, Any]:
    payload = decode_token(data.refresh_token, secret=REFRESH_SECRET)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token.")

    user_id = int(payload.get("sub"))
    r_hash = refresh_hash(data.refresh_token)

    with get_db() as conn:
        cursor = conn.cursor()
        session = cursor.execute(
            "SELECT * FROM refresh_sessions WHERE user_id = ? AND refresh_hash = ? AND revoked = 0",
            (user_id, r_hash),
        ).fetchone()

        if not session or session["expires_at"] < now_utc().isoformat():
            raise HTTPException(status_code=401, detail="Refresh session expired or revoked.")

        cursor.execute("UPDATE refresh_sessions SET revoked = 1 WHERE id = ?", (session["id"],))
        new_acc_token = access_token(user_id)
        new_ref_token = refresh_token(user_id)
        cursor.execute(
            """
            INSERT INTO refresh_sessions (user_id, refresh_hash, device_id, created_at, expires_at, revoked)
            VALUES (?, ?, 'mobile', ?, ?, 0)
            """,
            (
                user_id,
                refresh_hash(new_ref_token),
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
            ),
        )

        user = cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        return auth_success_payload(dict(user), new_acc_token, new_ref_token)


@router.post("/auth/logout-all")
def logout_all(user: dict[str, Any] = Depends(auth_user)) -> dict[str, str]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE refresh_sessions SET revoked = 1 WHERE user_id = ?", (user["id"],))
    return {"status": "success", "message": "All sessions revoked."}


@router.get("/auth/me")
@router.get("/profile")
def get_profile(user: dict[str, Any] = Depends(auth_user)) -> dict[str, Any]:
    return {
        "status": "success",
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


@router.put("/profile")
def update_profile(
    data: ProfileUpdateIn,
    user: dict[str, Any] = Depends(auth_user),
) -> dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        fields = []
        params = []
        if data.full_name is not None:
            fields.append("full_name = ?")
            params.append(data.full_name.strip())
        if data.email is not None:
            fields.append("email = ?")
            params.append(data.email.strip().lower())
        if data.auto_delete_logs is not None:
            fields.append("auto_delete_logs = ?")
            params.append(1 if data.auto_delete_logs else 0)
        if data.two_fa_enabled is not None:
            fields.append("two_fa_enabled = ?")
            params.append(1 if data.two_fa_enabled else 0)

        if fields:
            params.append(user["id"])
            cursor.execute(f"UPDATE users SET {', '.join(fields)} WHERE id = ?", params)

        updated = cursor.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
        return {
            "status": "success",
            "user": {
                "id": updated["id"],
                "full_name": updated["full_name"],
                "email": updated["email"],
                "phone": updated["phone"],
                "two_fa_enabled": bool(updated["two_fa_enabled"]),
                "auto_delete_logs": bool(updated["auto_delete_logs"]),
                "created_at": updated["created_at"],
            },
        }
