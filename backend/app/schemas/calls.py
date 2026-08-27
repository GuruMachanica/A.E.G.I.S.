"""
Call Records & Live Audio Processing Schemas
"""
from typing import Any, Optional
from pydantic import BaseModel, Field


class CallRecordPayload(BaseModel):
    id: str
    contact_name: Optional[str] = "Unknown"
    phone_number: str
    timestamp: str
    duration_seconds: int = 0
    threat_level: str = "SAFE"
    ai_risk_score: float = 0.0
    voice_risk_score: float = 0.0
    intent_risk_score: float = 0.0
    detected_keywords: list[str] = []
    summary: Optional[str] = ""
    transcript: Optional[str] = ""


class CallRecordSyncIn(BaseModel):
    records: list[CallRecordPayload]


class LiveCallStartIn(BaseModel):
    call_number: Optional[str] = "Unknown"
    sample_rate: int = 16000
    channels: int = 1


class LiveCallStartOut(BaseModel):
    call_id: str
    status: str
    started_at: str


class LiveCallChunkOut(BaseModel):
    call_id: str
    synthetic_voice_score: float
    scam_intent_score: float
    overall_score: float
    label: str
    alert_level: str
    detected_keywords: list[str]
    has_speech: bool
    live_transcription: str


class LiveCallEndIn(BaseModel):
    call_id: str


class LiveCallEndOut(BaseModel):
    call_id: str
    status: str
    final_risk_score: float
    final_risk_level: str
    total_transcription: str
    detected_keywords: list[str]
