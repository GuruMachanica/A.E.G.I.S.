from typing import Any, Optional

from pydantic import BaseModel, EmailStr, Field


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=1)
    phone: str = Field(min_length=5)
    email: EmailStr
    password: str = Field(min_length=8)


class LoginIn(BaseModel):
    phone: str
    password: str


class GoogleLoginIn(BaseModel):
    email: EmailStr
    full_name: str = Field(min_length=1)
    google_id: str = Field(min_length=1)
    id_token: Optional[str] = None


class VerifyLoginOtpIn(BaseModel):
    pending_token: str
    otp: str = Field(min_length=6, max_length=6)


class RefreshIn(BaseModel):
    refresh_token: str


class ResetRequestIn(BaseModel):
    phone: str


class PasswordUpdateIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8)


class SetPasswordIn(BaseModel):
    phone: Optional[str] = None
    new_password: str = Field(min_length=8)


class Start2FAIn(BaseModel):
    channel: str = "email"
    destination: Optional[str] = None


class Verify2FAIn(BaseModel):
    otp: str = Field(min_length=6, max_length=6)


class ProfileIn(BaseModel):
    full_name: str
    email: EmailStr
    auto_delete_logs: bool
    two_fa_enabled: bool


class SyncHistoryIn(BaseModel):
    records: list[dict[str, Any]]
