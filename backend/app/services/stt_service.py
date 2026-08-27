"""
Async Sarvam Speech-to-Text (STT) Service
"""
import logging
from typing import Optional
import aiohttp
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import (
    SARVAM_API_KEY,
    SARVAM_ENABLED,
    SARVAM_STT_ENDPOINT,
    SARVAM_TIMEOUT_SEC,
)
from app.services.audio_service import pcm_to_wav, check_speech_vad

logger = logging.getLogger(__name__)


class SarvamSTTService:
    def __init__(self) -> None:
        self.api_key = SARVAM_API_KEY
        self.endpoint = SARVAM_STT_ENDPOINT
        self.enabled = SARVAM_ENABLED and bool(self.api_key)

    @retry(
        stop=stop_after_attempt(2),
        wait=wait_exponential(multiplier=0.5, min=0.5, max=2.0),
        reraise=False,
    )
    async def _post_audio(self, wav_bytes: bytes, language_code: str = "hi-IN") -> Optional[str]:
        timeout = aiohttp.ClientTimeout(total=SARVAM_TIMEOUT_SEC)
        headers = {"api-subscription-key": self.api_key}

        data = aiohttp.FormData()
        data.add_field(
            "file",
            wav_bytes,
            filename="chunk.wav",
            content_type="audio/wav",
        )
        data.add_field("model", "saarika:v1")
        data.add_field("language_code", language_code)

        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(self.endpoint, headers=headers, data=data) as resp:
                if resp.status != 200:
                    body = await resp.text()
                    logger.warning(f"Sarvam STT returned HTTP {resp.status}: {body}")
                    return None
                result = await resp.json()
                return result.get("transcript", "").strip()

    async def transcribe_pcm(
        self,
        pcm_bytes: bytes,
        sample_rate: int = 16000,
        channels: int = 1,
        language_code: str = "hi-IN",
        require_vad: bool = True,
    ) -> Optional[str]:
        """Convert PCM bytes to WAV, perform VAD check, and request transcription from Sarvam."""
        if not self.enabled:
            return None

        if require_vad and not check_speech_vad(pcm_bytes, sample_rate):
            return None

        wav_bytes = pcm_to_wav(pcm_bytes, sample_rate, channels)
        try:
            return await self._post_audio(wav_bytes, language_code=language_code)
        except Exception as exc:
            logger.warning(f"Sarvam STT failed: {exc}")
            return None


# Global singleton instance
stt_service = SarvamSTTService()
