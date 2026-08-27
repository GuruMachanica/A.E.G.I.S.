"""
Pydantic Schemas Package for A.E.G.I.S
"""
from .auth import (
    RegisterIn,
    LoginIn,
    GoogleLoginIn,
    Start2FAIn,
    Verify2FAIn,
    VerifyLoginOtpIn,
    RefreshIn,
    PasswordUpdateIn,
    ResetRequestIn,
    SetPasswordIn,
)
from .calls import (
    CallRecordPayload,
    CallRecordSyncIn,
    LiveCallStartIn,
    LiveCallStartOut,
    LiveCallChunkOut,
    LiveCallEndIn,
    LiveCallEndOut,
)

__all__ = [
    "RegisterIn",
    "LoginIn",
    "GoogleLoginIn",
    "Start2FAIn",
    "Verify2FAIn",
    "VerifyLoginOtpIn",
    "RefreshIn",
    "PasswordUpdateIn",
    "ResetRequestIn",
    "SetPasswordIn",
    "CallRecordPayload",
    "CallRecordSyncIn",
    "LiveCallStartIn",
    "LiveCallStartOut",
    "LiveCallChunkOut",
    "LiveCallEndIn",
    "LiveCallEndOut",
]
