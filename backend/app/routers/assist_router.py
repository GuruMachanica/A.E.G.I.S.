import base64
import asyncio
import hashlib
import importlib
import json
import logging
import secrets
import time
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Any, Optional

import soundfile as sf
from fastapi import (
    APIRouter,
    File,
    HTTPException,
    Request,
    Response,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import simpleSplit
from reportlab.pdfgen import canvas

from ..config import INTENT_SCAN_DEBOUNCE_SEC
from ..db import get_db
from ..ml.intent_scanner import IntentRiskScanner
from ..ml.runtime import scoring_service
from ..ml.sarvam_stt import classify_scam_alert, sarvam_stt


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/assist", tags=["assist"])


def _audio_intent_model_loaded() -> bool:
    try:
        status = scoring_service.status()
        return bool(status.get("intent_model", {}).get("loaded", False))
    except Exception:
        return False


_SENSITIVE_KEYWORDS = {
    "credit card",
    "kyc",
    "otp",
    "cvv",
    "pin",
    "password",
    "bank account",
    "ifsc",
    "money",
    "paisa",
    "paise",
    "transfer",
    "transfer money",
    "send money",
    "upi pin",
    "aadhaar",
    "ssn",
}

_HTTP_LIVE_SESSIONS: dict[str, dict[str, Any]] = {}
_HTTP_SESSION_TTL_SEC = 60 * 30


def _cleanup_http_sessions() -> None:
    now = time.time()
    stale = [
        call_id
        for call_id, session in _HTTP_LIVE_SESSIONS.items()
        if (
            now - float(session.get("updated_at", now))
        ) > _HTTP_SESSION_TTL_SEC
    ]
    for call_id in stale:
        _HTTP_LIVE_SESSIONS.pop(call_id, None)


def _new_http_session(call_number: str) -> dict[str, Any]:
    call_id = f"call-{secrets.token_hex(8)}"
    started_at = datetime.now(timezone.utc).isoformat()
    session: dict[str, Any] = {
        "call_id": call_id,
        "call_number": call_number or "Unknown",
        "started_at": started_at,
        "sample_rate": 16000,
        "channels": 1,
        "pcm_buffer": bytearray(),
        "stt_buffer": bytearray(),
        "transcript_parts": [],
        "detected_keywords": set(),
        "ema_voice": None,
        "ema_overall": None,
        "transcript_intent_score": 0.0,
        "intent_source": "none",
        "last_scanned_transcript_hash": "",
        "last_intent_scan_at": 0.0,
        "last_stt_at": 0.0,
        "last_score_at": 0.0,
        "scam_alert_type": None,
        "scam_alert_message": None,
        "scam_alert_active": False,
        "updated_at": time.time(),
        "last_payload": {
            "call_id": call_id,
            "transcript": "",
            "detected_keywords": [],
            "synthetic_voice_score": 0.0,
            "audio_intent_score": 0.0,
            "transcript_intent_score": 0.0,
            "scam_intent_score": 0.0,
            "overall_score": 0.0,
            "risk_level": "safe",
            "intent_source": "none",
            "scam_alert_type": None,
            "scam_alert_message": None,
            "scam_alert_active": False,
            "sensitive_alert": False,
        },
    }
    _HTTP_LIVE_SESSIONS[call_id] = session
    return session


def _get_http_session_or_404(call_id: str) -> dict[str, Any]:
    _cleanup_http_sessions()
    session = _HTTP_LIVE_SESSIONS.get(call_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Live session not found.")
    return session


def _smooth(prev: float | None, current: float, alpha: float = 0.35) -> float:
    if prev is None:
        return current
    return (alpha * current) + ((1.0 - alpha) * prev)


def _apply_transcript_to_session(
    session: dict[str, Any],
    snippet: str,
    intent_scanner: IntentRiskScanner,
) -> None:
    cleaned = snippet.strip()
    if not cleaned:
        return

    transcript_parts = session["transcript_parts"]
    transcript_parts.append(cleaned)
    if len(transcript_parts) > 80:
        session["transcript_parts"] = transcript_parts[-80:]
        transcript_parts = session["transcript_parts"]

    detected_keywords = session["detected_keywords"]
    for keyword in _extract_keywords(cleaned):
        detected_keywords.add(keyword)

    now_monotonic = time.monotonic()
    full_transcript = " ".join(transcript_parts).strip()
    transcript_hash = hashlib.sha256(
        full_transcript.encode("utf-8")
    ).hexdigest()
    should_scan = (
        transcript_hash != session["last_scanned_transcript_hash"]
        and (
            now_monotonic - float(session["last_intent_scan_at"])
            >= max(0.0, INTENT_SCAN_DEBOUNCE_SEC)
        )
    )
    if should_scan:
        score, source = intent_scanner.scan(full_transcript)
        session["transcript_intent_score"] = score
        session["intent_source"] = source
        session["last_scanned_transcript_hash"] = transcript_hash
        session["last_intent_scan_at"] = now_monotonic


async def _run_stt_for_session(
    session: dict[str, Any],
    intent_scanner: IntentRiskScanner,
) -> None:
    sample_rate = int(session["sample_rate"])
    channels = int(session["channels"])
    stt_buffer = session["stt_buffer"]
    min_stt_bytes = int(1.0 * sample_rate * channels * 2)

    now_mono = time.monotonic()
    if len(stt_buffer) < min_stt_bytes:
        return
    if (now_mono - float(session["last_stt_at"])) < 1.0:
        return

    audio_for_stt = bytes(stt_buffer[-min_stt_bytes:])
    session["stt_buffer"] = bytearray()
    session["last_stt_at"] = now_mono

    transcript = await sarvam_stt.transcribe(
        audio_for_stt,
        sample_rate=sample_rate,
        channels=channels,
    )
    if not transcript:
        return

    _apply_transcript_to_session(session, transcript, intent_scanner)

    alert_type, alert_msg = classify_scam_alert(transcript)
    if alert_type:
        session["scam_alert_type"] = alert_type
        session["scam_alert_message"] = alert_msg
        session["scam_alert_active"] = True


def _risk_level(score: float) -> str:
    if score >= 0.65:
        return "danger"
    if score >= 0.35:
        return "warning"
    return "safe"


def _extract_keywords(text: str) -> list[str]:
    lowered = text.lower()
    return [kw for kw in sorted(_SENSITIVE_KEYWORDS) if kw in lowered]


def _latest_ai_call_log() -> Optional[dict[str, Any]]:
    conn = get_db()
    row = conn.execute(
        """
        SELECT *
        FROM ai_call_logs
        ORDER BY updated_at DESC
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return None

    try:
        keywords = json.loads(row["detected_keywords_json"])
    except Exception:
        keywords = []
    try:
        payload = json.loads(row["raw_payload_json"])
    except Exception:
        payload = {}

    return {
        "call_id": row["call_id"],
        "call_number": row["call_number"] or "Unknown",
        "transcription": row["transcription"],
        "detected_keywords": keywords if isinstance(keywords, list) else [],
        "risk_score": float(row["risk_score"]),
        "risk_level": row["risk_level"],
        "started_at": row["started_at"],
        "updated_at": row["updated_at"],
        "raw": payload,
    }


def _register_unicode_font() -> tuple[str, str]:
    """Register a TTF font that supports Hindi/Devanagari glyphs."""
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    candidates = [
        ("NirmalaUI", Path("C:/Windows/Fonts/Nirmala.ttf")),
        ("NirmalaUI", Path("C:/Windows/Fonts/nirmala.ttf")),
        (
            "DejaVuSans",
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        ),
    ]
    bold_candidates = [
        ("NirmalaUI-Bold", Path("C:/Windows/Fonts/NirmalaB.ttf")),
        ("NirmalaUI-Bold", Path("C:/Windows/Fonts/nirmalab.ttf")),
        (
            "DejaVuSans-Bold",
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
        ),
    ]

    font_name = "Helvetica"
    bold_name = "Helvetica-Bold"

    for name, path in candidates:
        if path.exists():
            try:
                pdfmetrics.registerFont(TTFont(name, str(path)))
                font_name = name
                break
            except Exception:
                pass

    for name, path in bold_candidates:
        if path.exists():
            try:
                pdfmetrics.registerFont(TTFont(name, str(path)))
                bold_name = name
                break
            except Exception:
                pass

    return font_name, bold_name


def _render_analysis_pdf(analysis: dict[str, Any]) -> bytes:
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 50

    uni_font, uni_bold = _register_unicode_font()

    def draw_line(text: str, bold: bool = False, size: int = 11) -> None:
        nonlocal y
        font = uni_bold if bold else uni_font
        pdf.setFont(font, size)
        wrapped = simpleSplit(text, font, size, width - 80)
        for part in wrapped:
            if y < 60:
                pdf.showPage()
                y = height - 50
                pdf.setFont(font, size)
            pdf.drawString(40, y, part)
            y -= 16

    draw_line("A.E.G.I.S. AI Call Analysis Report", bold=True, size=15)
    y -= 8
    draw_line(f"Call ID: {analysis['call_id']}")
    draw_line(f"Call Number: {analysis['call_number']}")
    draw_line(f"Started At: {analysis['started_at']}")
    draw_line(f"Updated At: {analysis['updated_at']}")
    risk_percent = int(round(analysis["risk_score"] * 100))
    draw_line(f"Risk: {analysis['risk_level']} ({risk_percent}%)", bold=True)
    y -= 8

    draw_line("Detected Keywords:", bold=True)
    keywords = analysis["detected_keywords"]
    if keywords:
        for kw in keywords:
            draw_line(f"- {kw}")
    else:
        draw_line("- None")

    y -= 8
    draw_line("Voice-to-Text Transcription:", bold=True)
    transcription = (
        analysis["transcription"].strip()
        or "No transcription captured."
    )
    draw_line(transcription)

    pdf.showPage()
    pdf.save()
    content = buffer.getvalue()
    buffer.close()
    return content


def _persist_stream_log(
    call_id: str,
    call_number: str,
    started_at: str,
    transcript_parts: list[str],
    detected_keywords: set[str],
    payload: dict[str, object],
) -> None:
    conn = get_db()
    now = datetime.now(timezone.utc).isoformat()
    transcription = " ".join(part for part in transcript_parts if part).strip()
    keywords_json = json.dumps(sorted(detected_keywords))
    conn.execute(
        """
        INSERT INTO ai_call_logs(
            call_id,
            call_number,
            transcription,
            detected_keywords_json,
            risk_score,
            risk_level,
            started_at,
            updated_at,
            raw_payload_json
        )
        VALUES(?,?,?,?,?,?,?,?,?)
        ON CONFLICT(call_id) DO UPDATE SET
            call_number = excluded.call_number,
            transcription = excluded.transcription,
            detected_keywords_json = excluded.detected_keywords_json,
            risk_score = excluded.risk_score,
            risk_level = excluded.risk_level,
            updated_at = excluded.updated_at,
            raw_payload_json = excluded.raw_payload_json
        """,
        (
            call_id,
            call_number,
            transcription,
            keywords_json,
            float(payload.get("overall_score", 0.0)),
            _risk_level(float(payload.get("overall_score", 0.0))),
            started_at,
            now,
            json.dumps(payload),
        ),
    )
    conn.commit()
    conn.close()


@router.get("/status")
def assist_status() -> dict[str, Any]:
    status = scoring_service.status()
    scanner = IntentRiskScanner()
    return {
        "ok": True,
        "assist": status.get("assist_fakevoice", {}),
        "target_sample_rate": status.get("target_sample_rate", 16000),
        "intent_scanner": {
            "enabled": scanner.enabled,
            "debounce_sec": INTENT_SCAN_DEBOUNCE_SEC,
        },
        "models": {
            "assist_fakevoice_loaded": bool(
                status.get("assist_fakevoice", {}).get("loaded", False)
            ),
            "audio_intent_model_loaded": bool(
                status.get("intent_model", {}).get("loaded", False)
            ),
            "sarvam_stt_enabled": bool(getattr(sarvam_stt, "enabled", False)),
        },
    }


@router.get("/analysis/latest")
def analysis_latest() -> dict[str, Any]:
    latest = _latest_ai_call_log()
    if latest is None:
        return {"ok": False, "message": "No AI call analysis found yet."}
    return {"ok": True, "analysis": latest}


@router.get("/analysis/latest/pdf")
def analysis_latest_pdf() -> Response:
    latest = _latest_ai_call_log()
    if latest is None:
        return Response(status_code=404, content=b"No analysis found.")

    data = _render_analysis_pdf(latest)
    return Response(
        content=data,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                "attachment; filename=aegis_ai_call_report.pdf"
            ),
        },
    )


@router.post("/live-audio/session/start")
async def live_audio_session_start(request: Request) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    try:
        parsed = await request.json()
        if isinstance(parsed, dict):
            payload = parsed
    except Exception:
        payload = {}

    call_number = (
        str(payload.get("call_number", "Unknown")).strip() or "Unknown"
    )
    session = _new_http_session(call_number)
    return {
        "ok": True,
        "call_id": session["call_id"],
        "call_number": session["call_number"],
        "sample_rate": session["sample_rate"],
        "channels": session["channels"],
    }


@router.post("/live-audio/transcript")
async def live_audio_transcript(
    call_id: str,
    request: Request,
) -> dict[str, Any]:
    session = _get_http_session_or_404(call_id)
    intent_scanner = IntentRiskScanner()

    payload: dict[str, Any] = {}
    try:
        parsed = await request.json()
        if isinstance(parsed, dict):
            payload = parsed
    except Exception:
        payload = {}

    text = str(payload.get("text", "")).strip()
    if text:
        _apply_transcript_to_session(session, text, intent_scanner)

    try:
        client_intent_score = float(payload.get("client_intent_score", 0.0))
    except Exception:
        client_intent_score = 0.0
    client_intent_score = max(0.0, min(1.0, client_intent_score))
    if client_intent_score > float(
        session.get("transcript_intent_score", 0.0)
    ):
        session["transcript_intent_score"] = client_intent_score
        if client_intent_score >= 0.7:
            session["intent_source"] = "client_rules"

    session["updated_at"] = time.time()
    return {
        "ok": True,
        "call_id": call_id,
        "transcript": " ".join(session["transcript_parts"]).strip(),
        "detected_keywords": sorted(session["detected_keywords"]),
    }


@router.post("/live-audio/chunk")
async def live_audio_chunk(
    call_id: str,
    request: Request,
    sample_rate: int = 16000,
    channels: int = 1,
) -> dict[str, Any]:
    session = _get_http_session_or_404(call_id)
    intent_scanner = IntentRiskScanner()

    body = await request.body()
    if not body:
        return {"ok": True, "analysis": session["last_payload"]}

    session["sample_rate"] = int(sample_rate or session["sample_rate"])
    session["channels"] = int(channels or session["channels"])
    session["pcm_buffer"].extend(body)
    session["stt_buffer"].extend(body)

    try:
        await _run_stt_for_session(session, intent_scanner)
    except Exception as stt_err:
        logger.warning("HTTP live STT error (non-fatal): %s", stt_err)

    now = time.monotonic()
    if (now - float(session["last_score_at"])) < 1.0:
        session["updated_at"] = time.time()
        return {"ok": True, "analysis": session["last_payload"]}
    session["last_score_at"] = now

    sample_rate = int(session["sample_rate"])
    channels = int(session["channels"])
    window_bytes = max(1, int(10 * sample_rate * channels * 2))
    max_buffer_bytes = window_bytes * 2
    if len(session["pcm_buffer"]) > max_buffer_bytes:
        session["pcm_buffer"] = session["pcm_buffer"][-max_buffer_bytes:]

    model_input = (
        bytes(session["pcm_buffer"][-window_bytes:])
        if len(session["pcm_buffer"]) >= window_bytes
        else bytes(session["pcm_buffer"])
    )
    if not model_input:
        return {"ok": True, "analysis": session["last_payload"]}

    raw_voice = 0.0
    audio_intent_score = 0.0
    energy_rms = 0.0
    payload: dict[str, Any] = {}
    min_score_bytes = sample_rate * channels * 2
    print(
        "[CHUNK DEBUG] "
        f"model_input={len(model_input)}B, "
        f"min_score_bytes={min_score_bytes}, "
        f"pcm_buffer={len(session['pcm_buffer'])}B"
    )
    if len(model_input) >= min_score_bytes:
        try:
            np_module = importlib.import_module("numpy")
            pcm = np_module.frombuffer(
                model_input,
                dtype=np_module.int16,
            ).astype(np_module.float32)
            if pcm.size > 0:
                energy_rms = float(
                    np_module.sqrt(
                        np_module.mean((pcm / 32768.0) ** 2) + 1e-12
                    )
                )
        except Exception:
            energy_rms = 0.0

        print(
            "[CHUNK DEBUG] "
            f"energy_rms={energy_rms:.6f}, "
            "threshold=0.008, "
            f"will_score={energy_rms >= 0.008}"
        )
        if energy_rms < 0.008:
            payload = {}
        else:
            try:
                payload = await asyncio.to_thread(
                    scoring_service.score,
                    model_input,
                    sample_rate=sample_rate,
                    channels=channels,
                )
                raw_voice = float(payload.get("synthetic_voice_score", 0.0))
                print(
                    "[CHUNK DEBUG] "
                    f"AASIST raw_voice={raw_voice:.4f}, "
                    f"payload_keys={list(payload.keys())}"
                )
                if _audio_intent_model_loaded():
                    audio_intent_score = float(
                        payload.get("scam_intent_score", 0.0)
                    )
                else:
                    audio_intent_score = 0.0
            except Exception as score_err:
                logger.warning(
                    "HTTP live scoring error (non-fatal): %s",
                    score_err,
                )
                print(f"[CHUNK DEBUG] SCORING ERROR: {score_err}")

    transcript_intent_score = float(session["transcript_intent_score"])
    combined_intent_score = max(
        0.0,
        min(1.0, max(transcript_intent_score, audio_intent_score)),
    )

    intent_source = str(session["intent_source"])
    if transcript_intent_score > 0 and audio_intent_score > 0:
        intent_source = "audio+transcript"
    elif transcript_intent_score > 0:
        intent_source = intent_source or "transcript"
    elif audio_intent_score > 0:
        intent_source = "audio"

    fused_overall = intent_scanner.fusion(raw_voice, combined_intent_score)
    if transcript_intent_score < 0.08 and combined_intent_score < 0.10:
        fused_overall = min(fused_overall, 0.35)
    if combined_intent_score >= 0.85:
        fused_overall = max(fused_overall, 0.85)
    if bool(session["scam_alert_active"]) and session["scam_alert_type"] in {
        "otp_asked",
        "money_asked",
        "bank_details_asked",
        "kyc_scam",
    }:
        fused_overall = max(fused_overall, 0.85)

    session["ema_voice"] = _smooth(session.get("ema_voice"), raw_voice)
    session["ema_overall"] = _smooth(session.get("ema_overall"), fused_overall)

    payload["synthetic_voice_score"] = round(float(session["ema_voice"]), 3)
    payload["audio_intent_score"] = round(audio_intent_score, 3)
    payload["transcript_intent_score"] = round(transcript_intent_score, 3)
    payload["scam_intent_score"] = round(combined_intent_score, 3)
    payload["intent_source"] = intent_source
    payload["overall_score"] = round(float(session["ema_overall"]), 3)
    payload["call_id"] = call_id
    payload["transcript"] = " ".join(session["transcript_parts"]).strip()
    payload["detected_keywords"] = sorted(session["detected_keywords"])
    payload["sensitive_alert"] = bool(session["detected_keywords"])
    payload["risk_level"] = _risk_level(float(payload["overall_score"]))
    if combined_intent_score >= 0.85:
        payload["risk_level"] = "danger"
    if bool(session["scam_alert_active"]) and session["scam_alert_type"] in {
        "otp_asked",
        "money_asked",
        "bank_details_asked",
        "kyc_scam",
    }:
        payload["risk_level"] = "danger"

    payload["scam_alert_type"] = session.get("scam_alert_type")
    payload["scam_alert_message"] = session.get("scam_alert_message")
    payload["scam_alert_active"] = bool(
        session.get("scam_alert_active", False)
    )
    payload["audio_energy_rms"] = round(energy_rms, 5)

    _persist_stream_log(
        call_id=call_id,
        call_number=str(session["call_number"]),
        started_at=str(session["started_at"]),
        transcript_parts=list(session["transcript_parts"]),
        detected_keywords=set(session["detected_keywords"]),
        payload=payload,
    )

    session["intent_source"] = intent_source
    session["last_payload"] = payload
    session["updated_at"] = time.time()
    return {"ok": True, "analysis": payload}


@router.get("/live-audio/state/{call_id}")
def live_audio_state(call_id: str) -> dict[str, Any]:
    session = _get_http_session_or_404(call_id)
    session["updated_at"] = time.time()
    return {"ok": True, "analysis": session["last_payload"]}


@router.post("/test")
async def analysis_test(file: UploadFile = File(...)) -> dict[str, Any]:
    filename = file.filename or "uploaded.wav"
    if not filename.lower().endswith((".wav", ".mp3")):
        raise HTTPException(
            status_code=400,
            detail="Only WAV or MP3 file is supported.",
        )

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    np_module = importlib.import_module("numpy")
    target_sr = int(scoring_service.status().get("target_sample_rate", 16000))

    try:
        if filename.lower().endswith(".wav"):
            audio, source_sr = sf.read(BytesIO(raw), dtype="float32")
        else:
            tmp = BytesIO(raw)
            librosa = importlib.import_module("librosa")
            audio, source_sr = librosa.load(tmp, sr=None, mono=True)
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail="Invalid audio content.",
        ) from exc

    if getattr(audio, "ndim", 1) > 1:
        audio = np_module.mean(audio, axis=1)

    if int(source_sr) != target_sr:
        librosa = importlib.import_module("librosa")
        audio = librosa.resample(
            audio,
            orig_sr=int(source_sr),
            target_sr=target_sr,
        )

    audio = np_module.clip(audio, -1.0, 1.0)
    audio_i16 = (audio * 32767.0).astype(np_module.int16)
    payload = scoring_service.score(
        audio_i16.tobytes(),
        sample_rate=target_sr,
        channels=1,
    )

    duration_sec = float(len(audio)) / float(max(1, target_sr))
    return {
        "ok": True,
        "filename": filename,
        "source_sample_rate": int(source_sr),
        "target_sample_rate": target_sr,
        "duration_sec": round(duration_sec, 3),
        "analysis": payload,
    }


async def _handle_live_audio(ws: WebSocket) -> None:
    await ws.accept()
    intent_scanner = IntentRiskScanner()
    call_id = f"call-{secrets.token_hex(8)}"
    pcm_buffer = bytearray()
    stt_buffer = bytearray()  # separate buffer for STT transcription
    sample_rate = 16000
    channels = 1
    call_number = "Unknown"
    transcript_parts: list[str] = []
    detected_keywords: set[str] = set()
    started_at = datetime.now(timezone.utc).isoformat()
    ema_voice: float | None = None
    ema_overall: float | None = None
    transcript_intent_score = 0.0
    intent_source = "none"
    last_scanned_transcript_hash = ""
    last_intent_scan_at = 0.0
    last_stt_at = 0.0
    stt_interval_sec = 1.0  # transcribe every 1 second for ultra-low latency
    scam_alert_type: str | None = None
    scam_alert_message: str | None = None
    scam_alert_active = False
    stt_inflight: asyncio.Task | None = None

    def _smooth(
        prev: float | None,
        current: float,
        alpha: float = 0.35,
    ) -> float:
        if prev is None:
            return current
        return (alpha * current) + ((1.0 - alpha) * prev)

    async def _safe_send(payload: dict[str, object]) -> bool:
        try:
            await ws.send_json(payload)
            return True
        except WebSocketDisconnect:
            return False
        except RuntimeError as exc:
            lower = str(exc).lower()
            if "close message" in lower or "disconnect" in lower:
                return False
            raise

    async def _process_stt_chunk(audio_for_stt: bytes) -> None:
        nonlocal transcript_intent_score, intent_source
        nonlocal last_scanned_transcript_hash, last_intent_scan_at
        nonlocal scam_alert_type, scam_alert_message, scam_alert_active

        transcript = await sarvam_stt.transcribe(
            audio_for_stt,
            sample_rate=sample_rate,
            channels=channels,
        )
        if not transcript:
            return

        transcript_parts.append(transcript)
        if len(transcript_parts) > 80:
            transcript_parts[:] = transcript_parts[-80:]
        for keyword in _extract_keywords(transcript):
            detected_keywords.add(keyword)

        full_transcript = " ".join(transcript_parts).strip()
        transcript_hash = hashlib.sha256(
            full_transcript.encode("utf-8")
        ).hexdigest()
        if transcript_hash != last_scanned_transcript_hash:
            score, source = intent_scanner.scan(full_transcript)
            transcript_intent_score = score
            intent_source = source
            last_scanned_transcript_hash = transcript_hash
            last_intent_scan_at = time.monotonic()

        alert_type, alert_msg = classify_scam_alert(transcript)
        if alert_type:
            scam_alert_type = alert_type
            scam_alert_message = alert_msg
            scam_alert_active = True

    async def _run_stt_if_needed() -> None:
        """Schedule Sarvam STT in background to keep websocket realtime."""
        nonlocal stt_buffer, last_stt_at, stt_inflight

        if stt_inflight is not None and stt_inflight.done():
            try:
                stt_inflight.result()
            except Exception as stt_err:
                logger.warning("Background STT task failed: %s", stt_err)
            finally:
                stt_inflight = None

        if stt_inflight is not None:
            return

        now_mono = time.monotonic()
        min_stt_bytes = int(stt_interval_sec * sample_rate * channels * 2)
        if len(stt_buffer) < min_stt_bytes:
            return
        if (now_mono - last_stt_at) < stt_interval_sec:
            return

        audio_for_stt = bytes(stt_buffer[-min_stt_bytes:])
        stt_buffer = bytearray()
        last_stt_at = now_mono
        stt_inflight = asyncio.create_task(_process_stt_chunk(audio_for_stt))

    last_score_at = 0.0  # throttle scoring to once per second

    async def _score_and_send() -> bool:
        nonlocal pcm_buffer, ema_voice, ema_overall, last_score_at
        now = time.monotonic()

        # Throttle: only score at most once per second
        if (now - last_score_at) < 1.0:
            return True
        last_score_at = now

        window_bytes = max(1, int(4 * sample_rate * channels * 2))
        max_buffer_bytes = window_bytes * 2
        if len(pcm_buffer) > max_buffer_bytes:
            pcm_buffer = pcm_buffer[-max_buffer_bytes:]

        model_input = (
            bytes(pcm_buffer[-window_bytes:])
            if len(pcm_buffer) >= window_bytes
            else bytes(pcm_buffer)
        )
        if not model_input:
            return True

        # Run STT scheduling — wrapped in try/except to never crash WS
        try:
            await _run_stt_if_needed()
        except Exception as stt_err:
            logger.warning("STT scheduling error (non-fatal): %s", stt_err)

        # Run intent/voice scoring safely
        raw_voice = 0.0
        audio_intent_score = 0.0
        min_score_bytes = sample_rate * channels * 2  # 1 second minimum
        if len(model_input) >= min_score_bytes:
            try:
                # CPU-bound inference is run in a thread to avoid WS blocking.
                payload = await asyncio.to_thread(
                    scoring_service.score,
                    model_input,
                    sample_rate=sample_rate,
                    channels=channels,
                )
                raw_voice = float(payload.get("synthetic_voice_score", 0.0))
                if _audio_intent_model_loaded():
                    audio_intent_score = float(
                        payload.get("scam_intent_score", 0.0)
                    )
                else:
                    audio_intent_score = 0.0
            except Exception as score_err:
                logger.warning(
                    "Voice scoring error (non-fatal): %s",
                    score_err,
                )
                payload = {}
        else:
            payload = {}

        combined_intent_score = max(
            0.0,
            min(1.0, max(transcript_intent_score, audio_intent_score)),
        )
        if transcript_intent_score > 0 and audio_intent_score > 0:
            intent_source = "audio+transcript"
        elif transcript_intent_score > 0:
            intent_source = intent_source or "transcript"
        elif audio_intent_score > 0:
            intent_source = "audio"

        fused_overall = intent_scanner.fusion(raw_voice, combined_intent_score)
        if transcript_intent_score < 0.08 and combined_intent_score < 0.10:
            fused_overall = min(fused_overall, 0.35)
        if combined_intent_score >= 0.85:
            fused_overall = max(fused_overall, 0.85)
        if scam_alert_active and scam_alert_type in {
            "otp_asked",
            "money_asked",
            "bank_details_asked",
            "kyc_scam",
        }:
            fused_overall = max(fused_overall, 0.85)
        ema_voice = _smooth(ema_voice, raw_voice)
        ema_overall = _smooth(ema_overall, fused_overall)

        payload["synthetic_voice_score"] = round(ema_voice, 3)
        payload["audio_intent_score"] = round(audio_intent_score, 3)
        payload["transcript_intent_score"] = round(transcript_intent_score, 3)
        payload["scam_intent_score"] = round(combined_intent_score, 3)
        payload["intent_source"] = intent_source
        payload["overall_score"] = round(ema_overall, 3)
        payload["call_id"] = call_id
        payload["transcript"] = " ".join(transcript_parts).strip()
        payload["detected_keywords"] = sorted(detected_keywords)
        payload["sensitive_alert"] = bool(detected_keywords)
        payload["risk_level"] = _risk_level(float(payload["overall_score"]))
        if combined_intent_score >= 0.85:
            payload["risk_level"] = "danger"
        if scam_alert_active and scam_alert_type in {
            "otp_asked",
            "money_asked",
            "bank_details_asked",
            "kyc_scam",
        }:
            payload["risk_level"] = "danger"

        # Scam alert fields
        payload["scam_alert_type"] = scam_alert_type
        payload["scam_alert_message"] = scam_alert_message
        payload["scam_alert_active"] = scam_alert_active

        _persist_stream_log(
            call_id=call_id,
            call_number=call_number,
            started_at=started_at,
            transcript_parts=transcript_parts,
            detected_keywords=detected_keywords,
            payload=payload,
        )
        return await _safe_send(payload)

    # ── Background Worker Queue ─────────────────────────────────
    audio_queue = asyncio.Queue()

    async def _audio_worker() -> None:
        """Processes audio chunks from the queue sequentially."""
        try:
            while True:
                # Wait for at least one chunk
                chunk = await audio_queue.get()
                pcm_buffer.extend(chunk)
                stt_buffer.extend(chunk)

                # Drain the queue instantly if multiple chunks arrived
                while not audio_queue.empty():
                    extra = audio_queue.get_nowait()
                    pcm_buffer.extend(extra)
                    stt_buffer.extend(extra)

                # Run scoring/STT
                keep_going = await _score_and_send()
                if not keep_going:
                    break
        except asyncio.CancelledError:
            pass
        except Exception as e:
            print(f"[Worker] Error: {e}")

    worker_task = asyncio.create_task(_audio_worker())

    # ── WebSocket receive loop ──────────────────────────────────
    try:
        print(f"[WS] === Entering receive loop for call {call_id} ===")
        while True:
            packet = await ws.receive()
            ptype = packet.get("type", "unknown")
            if ptype == "websocket.disconnect":
                print("[WS] Received disconnect packet")
                break

            # ── Binary frames (raw PCM audio) ──
            if "bytes" in packet and packet["bytes"] is not None:
                data = packet["bytes"] or b""
                audio_queue.put_nowait(data)

            # ── Text frames (JSON messages) ──
            elif "text" in packet and packet["text"] is not None:
                try:
                    message = json.loads(packet["text"])
                except Exception:
                    message = {}

                if not isinstance(message, dict):
                    continue

                msg_type = message.get("type", "")

                # Handle meta packet
                if msg_type == "meta":
                    meta = message.get("meta", {})
                    if isinstance(meta, dict):
                        sample_rate = int(
                            meta.get("sample_rate", sample_rate)
                            or sample_rate
                        )
                        channels = int(
                            meta.get("channels", channels)
                            or channels
                        )
                        meta_call = meta.get("call_number")
                        if isinstance(meta_call, str) and meta_call.strip():
                            call_number = meta_call.strip()
                    print(
                        "[WS] Meta received: "
                        f"sr={sample_rate} ch={channels} "
                        f"call={call_number}"
                    )

                # Handle base64-encoded audio chunks
                elif msg_type == "chunk":
                    b64 = str(message.get("pcm_base64", ""))
                    if b64:
                        try:
                            decoded = base64.b64decode(b64)
                            if decoded:
                                audio_queue.put_nowait(decoded)
                        except Exception:
                            pass

                # Handle transcript from client
                elif msg_type == "transcript":
                    snippet = str(message.get("text", "")).strip()
                    if snippet:
                        transcript_parts.append(snippet)
                        if len(transcript_parts) > 80:
                            transcript_parts = transcript_parts[-80:]
                        for keyword in _extract_keywords(snippet):
                            detected_keywords.add(keyword)

                        now_monotonic = time.monotonic()
                        full_transcript = " ".join(transcript_parts).strip()
                        transcript_hash = hashlib.sha256(
                            full_transcript.encode("utf-8")
                        ).hexdigest()
                        should_scan = (
                            transcript_hash != last_scanned_transcript_hash
                            and (
                                now_monotonic - last_intent_scan_at
                                >= max(0.0, INTENT_SCAN_DEBOUNCE_SEC)
                            )
                        )
                        if should_scan:
                            score, source = intent_scanner.scan(
                                full_transcript
                            )
                            transcript_intent_score = score
                            intent_source = source
                            last_scanned_transcript_hash = transcript_hash
                            last_intent_scan_at = now_monotonic

                # Also check top-level call_number field
                top_call = message.get("call_number")
                if isinstance(top_call, str) and top_call.strip():
                    call_number = top_call.strip()

    except WebSocketDisconnect:
        print(f"[WS] Client disconnected for call {call_id}")
    except RuntimeError as exc:
        lowered = str(exc).lower()
        if "disconnect" in lowered or "close message" in lowered:
            print(f"[WS] Runtime disconnect for call {call_id}")
            return
        raise
    except Exception as exc:
        print(f"[WS] UNEXPECTED ERROR: {exc}")
        raise
    finally:
        worker_task.cancel()
        if stt_inflight is not None and not stt_inflight.done():
            stt_inflight.cancel()


@router.websocket("/live-audio")
async def ws_live_audio(ws: WebSocket) -> None:
    await _handle_live_audio(ws)
