import json
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Header, Query

from ..db import get_db
from ..records import decode_payload_json, record_from_payload
from ..schemas import ProfileIn, SyncHistoryIn
from ..security import auth_user, iso, now_utc


router = APIRouter()


@router.put("/profile")
def update_profile(
    data: ProfileIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    conn = get_db()
    conn.execute(
        """
        UPDATE users
        SET full_name = ?, email = ?, auto_delete_logs = ?, two_fa_enabled = ?
        WHERE id = ?
        """,
        (
            data.full_name.strip(),
            data.email.lower(),
            1 if data.auto_delete_logs else 0,
            1 if data.two_fa_enabled else 0,
            int(user["id"]),
        ),
    )
    conn.commit()
    conn.close()
    return {"ok": True}


@router.get("/profile")
def get_profile(
    authorization: Optional[str] = Header(default=None),
) -> dict[str, Any]:
    user = auth_user(authorization)
    return {
        "user_id": str(user["id"]),
        "full_name": user["full_name"],
        "email": user["email"],
        "phone": user["phone"],
        "auto_delete_logs": bool(int(user["auto_delete_logs"])),
        "two_fa_enabled": bool(int(user["two_fa_enabled"])),
    }


@router.get("/history")
def get_history(
    authorization: Optional[str] = Header(default=None),
    limit: int = Query(default=100, ge=1, le=500),
) -> dict[str, Any]:
    user = auth_user(authorization)
    conn = get_db()
    rows = conn.execute(
        """
        SELECT id, payload_json, synced_at
        FROM call_records
        WHERE user_id = ?
        ORDER BY synced_at DESC
        LIMIT ?
        """,
        (int(user["id"]), limit),
    ).fetchall()
    conn.close()

    records: list[dict[str, Any]] = []
    for row in rows:
        payload = decode_payload_json(row["payload_json"])
        normalized = record_from_payload(payload)
        normalized["id"] = str(row["id"])
        records.append(normalized)

    def _call_time_key(item: dict[str, Any]) -> datetime:
        raw_value = item.get("callTime")
        try:
            return datetime.fromisoformat(str(raw_value))
        except (TypeError, ValueError):
            return datetime.min

    records.sort(key=_call_time_key, reverse=True)

    return {"records": records, "count": len(records)}


@router.post("/history/sync")
def sync_history(
    data: SyncHistoryIn,
    authorization: Optional[str] = Header(default=None),
) -> dict[str, Any]:
    user = auth_user(authorization)
    conn = get_db()
    synced_at = iso(now_utc())
    conn.execute(
        "DELETE FROM call_records WHERE user_id = ?",
        (int(user["id"]),),
    )
    for record in data.records:
        normalized = record_from_payload(record)
        rec_id = str(normalized["id"])
        conn.execute(
            """
            INSERT OR REPLACE INTO call_records(
                id,user_id,payload_json,synced_at
            )
            VALUES(?,?,?,?)
            """,
            (rec_id, int(user["id"]), json.dumps(normalized), synced_at),
        )
    conn.commit()
    conn.close()
    return {"ok": True, "count": len(data.records)}


@router.delete("/history")
def clear_history(
    authorization: Optional[str] = Header(default=None),
) -> dict[str, bool]:
    user = auth_user(authorization)
    conn = get_db()
    conn.execute(
        "DELETE FROM call_records WHERE user_id = ?",
        (int(user["id"]),),
    )
    conn.commit()
    conn.close()
    return {"ok": True}
