"""
Authentication Pydantic Schemas
"""
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class RegisterIn(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=120)
    email: EmailStr
    phone: str = Field(..., min_length=7, max_length=25)
    password: str = Field(..., min_length=6, max_length=128)


class LoginIn(BaseModel):
    login: str = Field(..., min_length=3)
    password: str = Field(..., min_length=1)


class GoogleLoginIn(BaseModel):
    id_token: str = Field(..., min_length=10)


class Start2FAIn(BaseModel):
    flow: str = Field(default="login", pattern="^(login|enable_2fa|reset_password)$")
    destination: Optional[str] = None


class Verify2FAIn(BaseModel):
    pending_token: str
    code: str = Field(..., min_length=4, max_length=10)


class VerifyLoginOtpIn(BaseModel):
    pending_token: str
    code: str = Field(..., min_length=4, max_length=10)


class RefreshIn(BaseModel):
    refresh_token: str


class PasswordUpdateIn(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6, max_length=128)


class ResetRequestIn(BaseModel):
    identifier: str = Field(..., min_length=3)


class SetPasswordIn(BaseModel):
    pending_token: str
    new_password: str = Field(..., min_length=6, max_length=128)
