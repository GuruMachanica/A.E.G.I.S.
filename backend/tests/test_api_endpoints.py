"""
Integration tests for FastAPI REST Endpoints & Authentication
"""
import uuid
import pytest
from fastapi.testclient import TestClient
from app.core.db import init_db
from main import app

# Ensure database tables are created
init_db()

client = TestClient(app)


def test_health_check():
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert "models" in data


def test_model_status():
    resp = client.get("/assist/models/status")
    assert resp.status_code == 200
    data = resp.json()
    assert "aasist_model" in data


def test_user_registration_and_login_flow():
    rand_email = f"test_{uuid.uuid4().hex[:8]}@example.com"
    rand_phone = f"+1{uuid.uuid4().int % 10000000000:010d}"

    reg_payload = {
        "full_name": "Test Security Officer",
        "email": rand_email,
        "phone": rand_phone,
        "password": "SecurePassword123!",
    }

    # 1. Register
    reg_resp = client.post("/auth/register", json=reg_payload)
    assert reg_resp.status_code == 200
    reg_data = reg_resp.json()
    assert reg_data["status"] == "success"
    assert "token" in reg_data
    token = reg_data["token"]

    # 2. Get Me
    me_resp = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_resp.status_code == 200
    me_data = me_resp.json()
    assert me_data["user"]["email"] == rand_email.lower()

    # 3. Login
    login_resp = client.post(
        "/auth/login",
        json={"login": rand_email, "password": "SecurePassword123!"},
    )
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert "token" in login_data


def test_live_call_http_lifecycle():
    # 1. Start live call session
    start_resp = client.post(
        "/assist/live-call/start",
        json={"call_number": "+919876543210", "sample_rate": 16000, "channels": 1},
    )
    assert start_resp.status_code == 200
    start_data = start_resp.json()
    call_id = start_data["call_id"]
    assert call_id.startswith("call-")

    # 2. End live call session
    end_resp = client.post(
        "/assist/live-call/end",
        json={"call_id": call_id},
    )
    assert end_resp.status_code == 200
    end_data = end_resp.json()
    assert end_data["status"] == "completed"
    assert end_data["call_id"] == call_id

    # 3. Download PDF report
    report_resp = client.get(f"/assist/report/{call_id}/pdf")
    assert report_resp.status_code == 200
    assert report_resp.headers["content-type"] == "application/pdf"
