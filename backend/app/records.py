import json
import secrets
from datetime import datetime
from typing import Any

from .security import iso, now_utc


def record_from_payload(raw: dict[str, Any]) -> dict[str, Any]:
    call_time_raw = raw.get("callTime") or raw.get("call_time")
    try:
        call_time = (
            datetime.fromisoformat(str(call_time_raw))
            if call_time_raw
            else now_utc()
        )
    except ValueError:
        call_time = now_utc()

    risk_score = int(raw.get("riskScore", raw.get("risk_score", 0)) or 0)
    synthetic_score = int(
        raw.get("syntheticScore", raw.get("synthetic_score", 0)) or 0
    )
    intent_score = int(raw.get("intentScore", raw.get("intent_score", 0)) or 0)

    if risk_score < 35:
        risk_level = "safe"
    elif risk_score < 65:
        risk_level = "suspicious"
    else:
        risk_level = "danger"

    return {
        "id": str(raw.get("id", f"r-{secrets.token_hex(8)}")),
        "callerName": str(
            raw.get("callerName", raw.get("caller_name", "Unknown"))
        ),
        "phoneNumber": str(
            raw.get("phoneNumber", raw.get("phone_number", "Unknown"))
        ),
        "callTime": iso(call_time),
        "riskLevel": risk_level,
        "riskScore": max(0, min(100, risk_score)),
        "syntheticScore": max(0, min(100, synthetic_score)),
        "intentScore": max(0, min(100, intent_score)),
        "isSuspended": bool(
            raw.get(
                "isSuspended",
                raw.get("is_suspended", risk_score >= 65),
            )
        ),
        "avatarAsset": raw.get("avatarAsset", raw.get("avatar_asset")),
    }


def decode_payload_json(raw: str) -> dict[str, Any]:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = {}
    return parsed if isinstance(parsed, dict) else {}
