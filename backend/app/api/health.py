"""
Health & Diagnostic API Router
"""
from typing import Any
from fastapi import APIRouter
from app.core.config import API_BASE_URL, SARVAM_ENABLED
from app.ml.runtime import scoring_service

router = APIRouter(tags=["health"])


@router.get("/")
def root() -> dict[str, str]:
    return {
        "service": "A.E.G.I.S Security Backend",
        "status": "online",
        "version": "2.0.0",
    }


@router.get("/health")
def health_check() -> dict[str, Any]:
    ml_status = scoring_service.status()
    return {
        "status": "healthy",
        "sarvam_stt_enabled": SARVAM_ENABLED,
        "models": ml_status,
    }


@router.get("/assist/models/status")
def model_status() -> dict[str, Any]:
    return scoring_service.status()
