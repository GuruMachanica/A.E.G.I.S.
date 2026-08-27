"""
Live Call Audio Processing & Threat Assessment Endpoints (WebSocket & HTTP)
"""
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import (
    APIRouter,
    File,
    HTTPException,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)

from app.core.config import ASSIST_TARGET_SAMPLE_RATE
from app.core.db import get_db
from app.ml.runtime import scoring_service
from app.schemas.calls import (
    LiveCallChunkOut,
    LiveCallEndIn,
    LiveCallEndOut,
    LiveCallStartIn,
    LiveCallStartOut,
)
from app.services.audio_service import check_speech_vad, slice_pcm_windows
from app.services.emergency_service import emergency_service
from app.services.lookup_service import phone_lookup_service
from app.services.risk_engine import RiskEngine
from app.services.session_manager import session_store
from app.services.stt_service import stt_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/assist", tags=["assist"])


@router.websocket("/live-audio")
async def live_audio_websocket(websocket: WebSocket) -> None:
    """Realtime WebSocket endpoint for continuous live PCM streaming & threat scoring."""
    await websocket.accept()
    session = await session_store.create_session(call_number="Live Call")

    try:
        while True:
            data = await websocket.receive()
            if data.get("type") == "websocket.disconnect":
                break

            # Handle text metadata messages
            if "text" in data and data["text"]:
                try:
                    payload = json.loads(data["text"])
                    if payload.get("type") == "meta":
                        meta = payload.get("meta", {})
                        session.sample_rate = int(meta.get("sample_rate", session.sample_rate))
                        session.channels = int(meta.get("channels", session.channels))
                        await websocket.send_text(json.dumps({"status": "meta_synced", "call_id": session.call_id}))
                except Exception:
                    pass
                continue

            # Binary audio PCM chunk
            if "bytes" in data and data["bytes"]:
                raw_bytes = data["bytes"]
                session.pcm_buffer.extend(raw_bytes)
                session.stt_buffer.extend(raw_bytes)

                # Process 4.04-second AASIST windows
                windows, consumed = slice_pcm_windows(
                    bytes(session.pcm_buffer),
                    sample_rate=session.sample_rate,
                    channels=session.channels,
                    window_seconds=4.04,
                )
                if windows:
                    session.pcm_buffer = session.pcm_buffer[consumed:]
                    for window in windows:
                        voice_score = scoring_service.score_audio_window(window, sample_rate=session.sample_rate)
                        session.ema_voice = (
                            voice_score if session.ema_voice is None else (0.6 * voice_score + 0.4 * session.ema_voice)
                        )

                # Process STT when buffer has >= 2.5s of speech
                stt_trigger_bytes = int(session.sample_rate * session.channels * 2 * 2.5)
                if len(session.stt_buffer) >= stt_trigger_bytes:
                    stt_chunk = bytes(session.stt_buffer)
                    session.stt_buffer.clear()

                    if check_speech_vad(stt_chunk, sample_rate=session.sample_rate):
                        transcript = await stt_service.transcribe_pcm(
                            stt_chunk,
                            sample_rate=session.sample_rate,
                            channels=session.channels,
                        )
                        if transcript:
                            session.transcript_parts.append(transcript)
                            kws, alerts, prim_alert = RiskEngine.extract_keywords_and_alerts(transcript)
                            session.detected_keywords.update(kws)
                            if prim_alert:
                                session.last_alert = prim_alert

                # Compute NLP Intent Risk & Hybrid Fusion
                full_text = session.full_transcript()
                intent_risk = RiskEngine.calculate_intent_risk(full_text)
                voice_risk = session.ema_voice or 0.0

                fused = RiskEngine.compute_hybrid_risk(voice_score=voice_risk, intent_score=intent_risk)

                response_frame = {
                    "call_id": session.call_id,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "synthetic_voice_score": fused["synthetic_voice_score"],
                    "scam_intent_score": fused["scam_intent_score"],
                    "overall_score": fused["overall_score"],
                    "label": fused["label"],
                    "alert_level": fused["alert_level"],
                    "alert_message": session.last_alert,
                    "detected_keywords": list(session.detected_keywords),
                    "live_transcription": full_text,
                }
                await websocket.send_text(json.dumps(response_frame))

    except WebSocketDisconnect:
        logger.info(f"WebSocket client disconnected for call {session.call_id}")
    finally:
        await session_store.remove_session(session.call_id)


@router.post("/live-call/start", response_model=LiveCallStartOut)
async def start_live_call(data: LiveCallStartIn) -> LiveCallStartOut:
    session = await session_store.create_session(
        call_number=data.call_number or "Unknown",
        sample_rate=data.sample_rate,
        channels=data.channels,
    )
    return LiveCallStartOut(
        call_id=session.call_id,
        status="active",
        started_at=session.started_at,
    )


@router.post("/live-call/chunk", response_model=LiveCallChunkOut)
async def process_live_call_chunk(
    call_id: str,
    file: UploadFile = File(...),
) -> LiveCallChunkOut:
    session = await session_store.get_session(call_id)
    if not session:
        raise HTTPException(status_code=404, detail="Live call session not found or expired.")

    pcm_bytes = await file.read()
    if not pcm_bytes:
        raise HTTPException(status_code=400, detail="Empty audio buffer received.")

    # Acoustic analysis
    score_res = scoring_service.score(pcm_bytes, sample_rate=session.sample_rate, channels=session.channels)
    voice_score = score_res["synthetic_voice_score"]

    # STT transcription
    transcript = await stt_service.transcribe_pcm(pcm_bytes, sample_rate=session.sample_rate, channels=session.channels)
    if transcript:
        session.transcript_parts.append(transcript)
        kws, alerts, prim_alert = RiskEngine.extract_keywords_and_alerts(transcript)
        session.detected_keywords.update(kws)

    full_text = session.full_transcript()
    intent_risk = RiskEngine.calculate_intent_risk(full_text)
    fused = RiskEngine.compute_hybrid_risk(voice_score=voice_score, intent_score=intent_risk)

    return LiveCallChunkOut(
        call_id=session.call_id,
        synthetic_voice_score=float(fused["synthetic_voice_score"]),
        scam_intent_score=float(fused["scam_intent_score"]),
        overall_score=float(fused["overall_score"]),
        label=str(fused["label"]),
        alert_level=str(fused["alert_level"]),
        detected_keywords=list(session.detected_keywords),
        has_speech=score_res["has_speech"],
        live_transcription=full_text,
    )


@router.post("/live-call/end", response_model=LiveCallEndOut)
async def end_live_call(data: LiveCallEndIn) -> LiveCallEndOut:
    session = await session_store.remove_session(data.call_id)
    if not session:
        raise HTTPException(status_code=404, detail="Live call session not found.")

    full_transcript = session.full_transcript()
    intent_risk = RiskEngine.calculate_intent_risk(full_transcript)
    fused = RiskEngine.compute_hybrid_risk(
        voice_score=session.ema_voice or 0.0,
        intent_score=intent_risk,
    )

    final_score = float(fused["overall_score"])
    final_level = str(fused["alert_level"])
    now_iso = datetime.now(timezone.utc).isoformat()
    keywords_list = list(session.detected_keywords)

    # Persist in DB
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO ai_call_logs (
                call_id, call_number, transcription, detected_keywords_json,
                risk_score, risk_level, started_at, updated_at, raw_payload_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session.call_id,
                session.call_number,
                full_transcript,
                json.dumps(keywords_list),
                final_score,
                final_level,
                session.started_at,
                now_iso,
                json.dumps({
                    "synthetic_voice_score": fused["synthetic_voice_score"],
                    "scam_intent_score": fused["scam_intent_score"],
                }),
            ),
        )

    return LiveCallEndOut(
        call_id=session.call_id,
        status="completed",
        final_risk_score=final_score,
        final_risk_level=final_level,
        total_transcription=full_transcript,
        detected_keywords=keywords_list,
    )


@router.get("/lookup/{phone_number}")
async def lookup_phone_threat(phone_number: str) -> dict[str, Any]:
    """Inspect phone number reputation, spam markers, and carrier prefix risk."""
    return phone_lookup_service.analyze_number(phone_number)


@router.post("/emergency/trigger")
async def trigger_emergency_alert(payload: dict[str, Any]) -> dict[str, Any]:
    """Trigger guardian emergency SOS notification when critical scam risk is flagged."""
    guardian_email = payload.get("guardian_email", "")
    user_name = payload.get("user_name", "AEGIS User")
    caller_number = payload.get("caller_number", "Unknown Caller")
    risk_score = float(payload.get("risk_score", 0.90))
    detected_keywords = payload.get("detected_keywords", [])
    risk_level = payload.get("risk_level", "DANGER")

    result = emergency_service.dispatch_threat_alert(
        guardian_email=guardian_email,
        user_name=user_name,
        caller_number=caller_number,
        risk_score=risk_score,
        detected_keywords=detected_keywords,
        risk_level=risk_level,
    )
    return result
