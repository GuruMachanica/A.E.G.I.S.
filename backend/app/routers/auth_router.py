import secrets
from datetime import datetime, timedelta
from typing import Any, Optional

import jwt
from fastapi import APIRouter, Header, HTTPException

from ..config import (
    JWT_SECRET,
    OTP_EXPIRY_SEC,
    REFRESH_SECRET,
    REFRESH_TOKEN_TTL_SEC,
    SMTP_HOST,
)
from ..db import get_db
from ..schemas import (
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
from ..security import (
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


router = APIRouter()


@router.post("/auth/register")
def register(data: RegisterIn) -> dict[str, Any]:
    conn = get_db()
    cursor = conn.cursor()
    existing = cursor.execute(
        "SELECT id FROM users WHERE email = ? OR phone = ?",
        (data.email.lower(), data.phone.strip()),
    ).fetchone()
    if existing:
        conn.close()
        raise HTTPException(status_code=409, detail="User already exists.")

    cursor.execute(
        """
        INSERT INTO users(
            full_name,email,phone,password_hash,two_fa_enabled,created_at
        )
        VALUES(?,?,?,?,0,?)
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
    user = cursor.execute(
        "SELECT * FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()

    token = access_token(user_id)
    refresh = refresh_token(user_id)
    cursor.execute(
        """
        INSERT INTO refresh_sessions(
            user_id,refresh_hash,device_id,created_at,expires_at,revoked
        )
        VALUES(?,?,?,?,?,0)
        """,
        (
            user_id,
            refresh_hash(refresh),
            "mobile",
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
        ),
    )
    conn.commit()
    conn.close()
    return auth_success_payload(user, token, refresh)


@router.post("/auth/login")
def login(data: LoginIn) -> dict[str, Any]:
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE phone = ?",
        (data.phone.strip(),),
    ).fetchone()
    if not user or not verify_password(data.password, user["password_hash"]):
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid credentials.")

    if int(user["two_fa_enabled"]) == 1:
        destination = user["email"].strip().lower()
        rate_limit_email(destination)
        otp = make_otp()
        pending = pending_token(int(user["id"]))
        conn.execute(
            """
            INSERT INTO otp_challenges(
                user_id,channel,destination,otp_hash,pending_token,
                status,attempts,created_at,expires_at
            )
            VALUES(?,?,?,?,?,'sent',0,?,?)
            """,
            (
                int(user["id"]),
                "email",
                destination,
                hash_otp(otp),
                pending,
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=OTP_EXPIRY_SEC)).isoformat(),
            ),
        )
        conn.commit()
        conn.close()
        send_email_otp(destination, otp, "Login verification")

        payload: dict[str, Any] = {
            "requires_otp": True,
            "pending_token": pending,
            "otp_channel": "EMAIL",
            "otp_destination_masked": mask_email(destination),
            "full_name": user["full_name"],
            "email": user["email"],
            "phone": user["phone"],
            "user_id": str(user["id"]),
        }
        if not SMTP_HOST:
            payload["otp"] = otp
        return payload

    token = access_token(int(user["id"]))
    refresh = refresh_token(int(user["id"]))
    conn.execute(
        """
        INSERT INTO refresh_sessions(
            user_id,refresh_hash,device_id,created_at,expires_at,revoked
        )
        VALUES(?,?,?,?,?,0)
        """,
        (
            int(user["id"]),
            refresh_hash(refresh),
            "mobile",
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
        ),
    )
    conn.commit()
    conn.close()
    return auth_success_payload(user, token, refresh)


@router.post("/auth/google-login")
def google_login(data: GoogleLoginIn) -> dict[str, Any]:
    normalized_email = data.email.lower().strip()
    resolved_name = data.full_name.strip()

    if data.id_token:
        try:
            claims = jwt.decode(
                data.id_token,
                options={
                    "verify_signature": False,
                    "verify_exp": False,
                    "verify_aud": False,
                },
                algorithms=["RS256", "HS256"],
            )
            token_email = str(claims.get("email", "")).strip().lower()
            token_name = str(claims.get("name", "")).strip()
            if token_email:
                normalized_email = token_email
            if token_name:
                resolved_name = token_name
        except Exception:
            pass

    conn = get_db()
    cursor = conn.cursor()
    user = cursor.execute(
        "SELECT * FROM users WHERE email = ?", (normalized_email,)
    ).fetchone()

    if not user:
        synthetic_phone = f"google-{data.google_id.strip()[:32]}"
        if cursor.execute(
            "SELECT id FROM users WHERE phone = ?", (synthetic_phone,)
        ).fetchone():
            synthetic_phone = f"google-{now_utc().timestamp():.0f}"

        cursor.execute(
            """
            INSERT INTO users(
                full_name,email,phone,password_hash,two_fa_enabled,created_at
            )
            VALUES(?,?,?,?,0,?)
            """,
            (
                resolved_name,
                normalized_email,
                synthetic_phone,
                hash_password(secrets.token_urlsafe(24)),
                now_utc().isoformat(),
            ),
        )
        user_id = cursor.lastrowid
        user = cursor.execute(
            "SELECT * FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
    else:
        user_id = int(user["id"])
        if resolved_name and resolved_name != user["full_name"]:
            cursor.execute(
                "UPDATE users SET full_name = ? WHERE id = ?",
                (resolved_name, user_id),
            )
            user = cursor.execute(
                "SELECT * FROM users WHERE id = ?",
                (user_id,),
            ).fetchone()

    token = access_token(int(user["id"]))
    refresh = refresh_token(int(user["id"]))
    cursor.execute(
        """
        INSERT INTO refresh_sessions(
            user_id,refresh_hash,device_id,created_at,expires_at,revoked
        )
        VALUES(?,?,?,?,?,0)
        """,
        (
            int(user["id"]),
            refresh_hash(refresh),
            "google-mobile",
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
        ),
    )
    conn.commit()
    conn.close()
    return auth_success_payload(user, token, refresh)


@router.post("/auth/login/verify-otp")
def verify_login_otp(data: VerifyLoginOtpIn) -> dict[str, Any]:
    pending = decode_token(JWT_SECRET, data.pending_token)
    if pending.get("type") != "pending":
        raise HTTPException(status_code=401, detail="Invalid pending token.")
    user_id = int(pending["sub"])

    conn = get_db()
    row = conn.execute(
        """
        SELECT * FROM otp_challenges
        WHERE user_id = ? AND status = 'sent'
        ORDER BY id DESC LIMIT 1
        """,
        (user_id,),
    ).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=400, detail="No OTP challenge found.")

    if now_utc() > datetime.fromisoformat(row["expires_at"]):
        conn.execute(
            "UPDATE otp_challenges SET status = 'expired' WHERE id = ?",
            (row["id"],),
        )
        conn.commit()
        conn.close()
        raise HTTPException(status_code=400, detail="OTP expired.")

    if hash_otp(data.otp) != row["otp_hash"]:
        conn.execute(
            "UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?",
            (row["id"],),
        )
        conn.commit()
        conn.close()
        raise HTTPException(status_code=400, detail="Invalid OTP.")

    conn.execute(
        "UPDATE otp_challenges SET status = 'verified' WHERE id = ?",
        (row["id"],),
    )
    user = conn.execute(
        "SELECT * FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    token = access_token(user_id)
    refresh = refresh_token(user_id)
    conn.execute(
        """
        INSERT INTO refresh_sessions(
            user_id,refresh_hash,device_id,created_at,expires_at,revoked
        )
        VALUES(?,?,?,?,?,0)
        """,
        (
            user_id,
            refresh_hash(refresh),
            "mobile",
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
        ),
    )
    conn.commit()
    conn.close()
    return auth_success_payload(user, token, refresh)


@router.post("/auth/refresh")
def refresh(data: RefreshIn) -> dict[str, Any]:
    payload = decode_token(REFRESH_SECRET, data.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token.")

    user_id = int(payload["sub"])
    token_hash = refresh_hash(data.refresh_token)
    conn = get_db()
    row = conn.execute(
        """
        SELECT * FROM refresh_sessions
        WHERE user_id = ? AND refresh_hash = ? AND revoked = 0
        ORDER BY id DESC LIMIT 1
        """,
        (user_id, token_hash),
    ).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=401, detail="Refresh session invalid.")

    if now_utc() > datetime.fromisoformat(row["expires_at"]):
        conn.execute(
            "UPDATE refresh_sessions SET revoked = 1 WHERE id = ?",
            (row["id"],),
        )
        conn.commit()
        conn.close()
        raise HTTPException(status_code=401, detail="Refresh session expired.")

    conn.execute(
        "UPDATE refresh_sessions SET revoked = 1 WHERE id = ?",
        (row["id"],),
    )
    new_refresh = refresh_token(user_id)
    conn.execute(
        """
        INSERT INTO refresh_sessions(
            user_id,refresh_hash,device_id,created_at,expires_at,revoked
        )
        VALUES(?,?,?,?,?,0)
        """,
        (
            user_id,
            refresh_hash(new_refresh),
            "mobile",
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=REFRESH_TOKEN_TTL_SEC)).isoformat(),
        ),
    )
    user = conn.execute(
        "SELECT * FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    conn.commit()
    conn.close()
    return auth_success_payload(user, access_token(user_id), new_refresh)


@router.post("/auth/logout-all")
def logout_all(
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    conn = get_db()
    conn.execute(
        "UPDATE refresh_sessions SET revoked = 1 WHERE user_id = ?",
        (int(user["id"]),),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@router.post("/auth/password/reset-request")
def password_reset_request(data: ResetRequestIn) -> dict[str, bool]:
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE phone = ?",
        (data.phone.strip(),),
    ).fetchone()
    if user:
        rate_limit_email(user["email"])
        otp = make_otp()
        conn.execute(
            """
            INSERT INTO otp_challenges(
                user_id,channel,destination,otp_hash,pending_token,
                status,attempts,created_at,expires_at
            )
            VALUES(?,?,?,?,?,'sent',0,?,?)
            """,
            (
                int(user["id"]),
                "email",
                user["email"],
                hash_otp(otp),
                pending_token(int(user["id"])),
                now_utc().isoformat(),
                (now_utc() + timedelta(seconds=OTP_EXPIRY_SEC)).isoformat(),
            ),
        )
        conn.commit()
        send_email_otp(user["email"], otp, "Password reset")
    conn.close()
    return {"ok": True}


@router.put("/auth/password")
def update_password(
    data: PasswordUpdateIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    if not verify_password(data.current_password, user["password_hash"]):
        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect.",
        )

    conn = get_db()
    conn.execute(
        "UPDATE users SET password_hash = ? WHERE id = ?",
        (hash_password(data.new_password), int(user["id"])),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@router.post("/auth/set-password")
def set_password(
    data: SetPasswordIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    phone = (data.phone or "").strip()
    conn = get_db()
    if phone:
        existing = conn.execute(
            "SELECT id FROM users WHERE phone = ? AND id != ?",
            (phone, int(user["id"])),
        ).fetchone()
        if existing:
            conn.close()
            raise HTTPException(
                status_code=409,
                detail="Phone already in use.",
            )
        conn.execute(
            "UPDATE users SET phone = ? WHERE id = ?",
            (phone, int(user["id"])),
        )

    conn.execute(
        "UPDATE users SET password_hash = ? WHERE id = ?",
        (hash_password(data.new_password), int(user["id"])),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@router.post("/auth/2fa/start")
def start_2fa(
    data: Start2FAIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, Any]:
    user = auth_user(authorization)
    destination = (data.destination or user["email"]).strip().lower()
    if data.channel.lower() != "email":
        raise HTTPException(
            status_code=400,
            detail="Only email channel is supported.",
        )

    rate_limit_email(destination)
    otp = make_otp()
    pending = pending_token(int(user["id"]))
    conn = get_db()
    conn.execute(
        """
        INSERT INTO otp_challenges(
            user_id,channel,destination,otp_hash,pending_token,
            status,attempts,created_at,expires_at
        )
        VALUES(?,?,?,?,?,'sent',0,?,?)
        """,
        (
            int(user["id"]),
            "email",
            destination,
            hash_otp(otp),
            pending,
            now_utc().isoformat(),
            (now_utc() + timedelta(seconds=OTP_EXPIRY_SEC)).isoformat(),
        ),
    )
    conn.commit()
    conn.close()

    send_email_otp(destination, otp, "2FA verification")
    response: dict[str, Any] = {
        "pending_token": pending,
        "otp_channel": "EMAIL",
        "otp_destination_masked": mask_email(destination),
    }
    if not SMTP_HOST:
        response["otp"] = otp
    return response


@router.post("/auth/2fa/verify")
def verify_2fa(
    data: Verify2FAIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    conn = get_db()
    row = conn.execute(
        """
        SELECT * FROM otp_challenges
        WHERE user_id = ? AND status = 'sent' AND channel = 'email'
        ORDER BY id DESC LIMIT 1
        """,
        (int(user["id"]),),
    ).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=400, detail="No active OTP challenge.")

    if now_utc() > datetime.fromisoformat(row["expires_at"]):
        conn.execute(
            "UPDATE otp_challenges SET status = 'expired' WHERE id = ?",
            (row["id"],),
        )
        conn.commit()
        conn.close()
        raise HTTPException(status_code=400, detail="OTP expired.")

    if hash_otp(data.otp.strip()) != row["otp_hash"]:
        conn.execute(
            "UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?",
            (row["id"],),
        )
        conn.commit()
        conn.close()
        raise HTTPException(status_code=400, detail="Invalid OTP.")

    conn.execute(
        "UPDATE otp_challenges SET status = 'verified' WHERE id = ?",
        (row["id"],),
    )
    conn.execute(
        "UPDATE users SET two_fa_enabled = 1 WHERE id = ?",
        (int(user["id"]),),
    )
    conn.commit()
    conn.close()
    return {"ok": True}
