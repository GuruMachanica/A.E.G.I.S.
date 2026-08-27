"""
Threat Assessment & PDF Report Generation Router
"""
import json
from typing import Any
from fastapi import APIRouter, HTTPException, Response

from app.core.db import get_db
from app.services.report_service import generate_call_report_pdf

router = APIRouter(tags=["reports"])


@router.get("/assist/report/{call_id}/pdf")
@router.get("/assist/analysis/{call_id}/pdf")
async def download_call_report_pdf(call_id: str) -> Response:
    with get_db() as conn:
        cursor = conn.cursor()
        if call_id == "latest":
            row = cursor.execute("SELECT * FROM ai_call_logs ORDER BY id DESC LIMIT 1").fetchone()
        else:
            row = cursor.execute("SELECT * FROM ai_call_logs WHERE call_id = ?", (call_id,)).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="AI Call Log reference not found.")

        keywords = []
        try:
            keywords = json.loads(row["detected_keywords_json"])
        except Exception:
            pass

        payload = {
            "call_id": row["call_id"],
            "call_number": row["call_number"] or "Unknown",
            "started_at": row["started_at"],
            "risk_score": row["risk_score"],
            "risk_level": row["risk_level"],
            "transcription": row["transcription"],
            "detected_keywords": keywords,
        }

    pdf_bytes = await generate_call_report_pdf(payload)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="aegis_report_{payload["call_id"]}.pdf"'},
    )


@router.get("/assist/report/{call_id}")
@router.get("/assist/analysis/{call_id}")
def get_call_report_data(call_id: str) -> dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        if call_id == "latest":
            row = cursor.execute("SELECT * FROM ai_call_logs ORDER BY id DESC LIMIT 1").fetchone()
        else:
            row = cursor.execute("SELECT * FROM ai_call_logs WHERE call_id = ?", (call_id,)).fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="AI Call Log reference not found.")

        keywords = []
        try:
            keywords = json.loads(row["detected_keywords_json"])
        except Exception:
            pass

        return {
            "status": "success",
            "call_id": row["call_id"],
            "call_number": row["call_number"],
            "risk_score": row["risk_score"],
            "risk_level": row["risk_level"],
            "transcription": row["transcription"],
            "detected_keywords": keywords,
            "started_at": row["started_at"],
            "updated_at": row["updated_at"],
        }
