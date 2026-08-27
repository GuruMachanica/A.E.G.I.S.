"""
Unit tests for PDF Report Generator
"""
import asyncio
from app.services.report_service import generate_call_report_pdf


def test_generate_call_report_pdf():
    payload = {
        "call_id": "call-test-123456",
        "call_number": "+1234567890",
        "started_at": "2026-08-27T10:00:00Z",
        "risk_score": 0.88,
        "risk_level": "DANGER",
        "transcription": "Caller urgently demanded UPI PIN and bank OTP under threat of account suspension.",
        "detected_keywords": ["otp", "upi pin", "bank account"],
    }

    pdf_bytes = asyncio.run(generate_call_report_pdf(payload))
    assert len(pdf_bytes) > 500
    assert pdf_bytes.startswith(b"%PDF")
