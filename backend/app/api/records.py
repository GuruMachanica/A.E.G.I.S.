"""
Call Records Sync & History API Router
"""
import json
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.db import get_db
from app.core.security import auth_user
from app.schemas.calls import CallRecordSyncIn

router = APIRouter(tags=["records"])


@router.post("/records/sync")
@router.post("/history/sync")
def sync_call_records(
    data: CallRecordSyncIn,
    user: dict[str, Any] = Depends(auth_user),
) -> dict[str, Any]:
    synced_at = datetime.now(timezone.utc).isoformat()
    synced_ids: list[str] = []

    with get_db() as conn:
        cursor = conn.cursor()
        for record in data.records:
            cursor.execute(
                """
                INSERT INTO call_records (id, user_id, payload_json, synced_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    payload_json = excluded.payload_json,
                    synced_at = excluded.synced_at
                """,
                (
                    record.id,
                    user["id"],
                    record.model_dump_json(),
                    synced_at,
                ),
            )
            synced_ids.append(record.id)

    return {
        "status": "success",
        "synced_count": len(synced_ids),
        "synced_ids": synced_ids,
        "synced_at": synced_at,
    }


@router.get("/records")
@router.get("/history")
def list_call_records(
    limit: int = Query(default=200, le=500),
    user: dict[str, Any] = Depends(auth_user),
) -> dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        rows = cursor.execute(
            "SELECT * FROM call_records WHERE user_id = ? ORDER BY synced_at DESC LIMIT ?",
            (user["id"], limit),
        ).fetchall()

        records = []
        for r in rows:
            try:
                payload = json.loads(r["payload_json"])
                records.append(payload)
            except Exception:
                pass

        return {"status": "success", "records": records}


@router.delete("/records/{record_id}")
def delete_call_record(
    record_id: str,
    user: dict[str, Any] = Depends(auth_user),
) -> dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM call_records WHERE id = ? AND user_id = ?",
            (record_id, user["id"]),
        )
        return {"status": "success", "deleted_id": record_id}


@router.delete("/history")
def clear_all_history(user: dict[str, Any] = Depends(auth_user)) -> dict[str, str]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM call_records WHERE user_id = ?", (user["id"],))
    return {"status": "success", "message": "Call history cleared."}
