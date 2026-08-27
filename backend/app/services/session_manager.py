"""
Thread-Safe Live Call Session Manager
"""
import asyncio
import secrets
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional


@dataclass
class CallSession:
    call_id: str
    call_number: str
    started_at: str
    sample_rate: int = 16000
    channels: int = 1
    pcm_buffer: bytearray = field(default_factory=bytearray)
    stt_buffer: bytearray = field(default_factory=bytearray)
    transcript_parts: list[str] = field(default_factory=list)
    detected_keywords: set[str] = field(default_factory=set)
    ema_voice: Optional[float] = None
    ema_intent: Optional[float] = None
    ema_overall: Optional[float] = None
    last_alert: Optional[str] = None
    updated_at: float = field(default_factory=time.time)

    def full_transcript(self) -> str:
        return " ".join(part for part in self.transcript_parts if part).strip()


class CallSessionStore:
    def __init__(self, ttl_seconds: int = 1800) -> None:
        self._sessions: dict[str, CallSession] = {}
        self._ttl_seconds = ttl_seconds
        self._lock = asyncio.Lock()

    async def create_session(
        self,
        call_number: str = "Unknown",
        sample_rate: int = 16000,
        channels: int = 1,
    ) -> CallSession:
        async with self._lock:
            self._cleanup_stale_unlocked()
            call_id = f"call-{secrets.token_hex(8)}"
            started_at = datetime.now(timezone.utc).isoformat()
            session = CallSession(
                call_id=call_id,
                call_number=call_number or "Unknown",
                started_at=started_at,
                sample_rate=sample_rate,
                channels=channels,
            )
            self._sessions[call_id] = session
            return session

    async def get_session(self, call_id: str) -> Optional[CallSession]:
        async with self._lock:
            session = self._sessions.get(call_id)
            if session:
                session.updated_at = time.time()
            return session

    async def remove_session(self, call_id: str) -> Optional[CallSession]:
        async with self._lock:
            return self._sessions.pop(call_id, None)

    def _cleanup_stale_unlocked(self) -> None:
        now = time.time()
        stale_ids = [
            cid for cid, sess in self._sessions.items()
            if (now - sess.updated_at) > self._ttl_seconds
        ]
        for cid in stale_ids:
            self._sessions.pop(cid, None)

    async def cleanup_stale(self) -> int:
        async with self._lock:
            before = len(self._sessions)
            self._cleanup_stale_unlocked()
            return before - len(self._sessions)


# Global singleton session store
session_store = CallSessionStore()
