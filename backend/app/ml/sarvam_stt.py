"""
Sarvam AI Speech-to-Text (STT) async client.

Sends PCM audio buffers to the Sarvam REST API endpoint
(https://api.sarvam.ai/speech-to-text) and returns the
transcribed text.
"""

import io
import logging
import wave
from typing import Optional

import aiohttp
import webrtcvad
from tenacity import retry, stop_after_attempt, wait_exponential

from ..config import (
    SARVAM_API_KEY,
    SARVAM_ENABLED,
    SARVAM_STT_ENDPOINT,
    SARVAM_TIMEOUT_SEC,
)


logger = logging.getLogger(__name__)


def _pcm_to_wav(
    pcm_bytes: bytes,
    sample_rate: int = 16000,
    channels: int = 1,
) -> bytes:
    """Convert raw PCM-16 LE bytes into a WAV file in memory."""
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit = 2 bytes
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    buf.seek(0)
    return buf.read()


def _has_speech(pcm_bytes: bytes, sample_rate: int = 16000) -> bool:
    """Use webrtcvad to detect if the buffer contains human speech."""
    if sample_rate not in (8000, 16000, 32000, 48000):
        # webrtcvad only supports these specific sample rates
        print(
            f"[VAD] Skipping VAD due to unsupported sample rate: {sample_rate}"
        )
        return True

    vad = webrtcvad.Vad(3)  # Aggressiveness: 3 (highest)
    # 30ms frames
    frame_duration_ms = 30
    bytes_per_frame = int(sample_rate * (frame_duration_ms / 1000.0) * 2)

    speech_frames = 0
    total_frames = 0

    for i in range(0, len(pcm_bytes) - bytes_per_frame + 1, bytes_per_frame):
        frame = pcm_bytes[i:i + bytes_per_frame]
        if len(frame) == bytes_per_frame:
            total_frames += 1
            if vad.is_speech(frame, sample_rate):
                speech_frames += 1

    if total_frames == 0:
        return False

    # True if at least 15% of frames contain speech
    ratio = speech_frames / total_frames
    has_speech = ratio >= 0.15
    print(f"[VAD] VAD check: {has_speech} (speech in {ratio:.1%} of frames)")
    return has_speech


_SCAM_ALERT_RULES: list[tuple[str, str, str]] = [
    # ── OTP / PIN / Password ──────────────────────────────────
    # English
    (
        "otp",
        "otp_asked",
        (
            "🚨 ALERT: Someone is asking for your OTP / verification code. "
            "NEVER share your OTP!"
        ),
    ),
    ("verification code", "otp_asked",
     "🚨 ALERT: Someone is asking for your verification code. NEVER share it!"),
    (
        "pin",
        "otp_asked",
        (
            "🚨 ALERT: Someone is asking for your PIN. "
            "NEVER share your PIN with anyone!"
        ),
    ),
    (
        "upi pin",
        "otp_asked",
        (
            "🚨 ALERT: Someone is asking for your UPI PIN. "
            "Banks NEVER ask for UPI PIN!"
        ),
    ),
    ("password", "otp_asked",
     "🚨 ALERT: Your password is being asked for. NEVER share passwords!"),
    # Hindi Devanagari (Sarvam STT output)
    ("ओटीपी", "otp_asked",
     "🚨 अलर्ट: कोई आपका OTP मांग रहा है। कभी OTP शेयर न करें!"),
    ("ओ टी पी", "otp_asked",
     "🚨 अलर्ट: कोई आपका OTP मांग रहा है। कभी OTP शेयर न करें!"),
    ("पिन", "otp_asked",
     "🚨 अलर्ट: कोई आपका PIN मांग रहा है। PIN शेयर न करें!"),
    ("यूपीआई पिन", "otp_asked",
     "🚨 अलर्ट: UPI PIN मांगा जा रहा है। बैंक कभी फोन पर PIN नहीं मांगता!"),
    ("पासवर्ड", "otp_asked",
     "🚨 अलर्ट: पासवर्ड मांगा जा रहा है। कभी पासवर्ड शेयर न करें!"),
    ("वेरिफिकेशन कोड", "otp_asked",
     "🚨 अलर्ट: वेरिफिकेशन कोड मांगा जा रहा है। शेयर न करें!"),
    # Hindi transliterated (romanized)
    ("otp batao", "otp_asked",
     "🚨 ALERT: Someone is asking for your OTP. NEVER share!"),
    ("otp bata", "otp_asked",
     "🚨 ALERT: Someone is asking for your OTP. NEVER share!"),
    ("otp do", "otp_asked",
     "🚨 ALERT: Someone is asking for your OTP. NEVER share!"),
    ("pin batao", "otp_asked",
     "🚨 ALERT: Someone asking for PIN. NEVER share!"),

    # ── Money / Payment ───────────────────────────────────────
    # English
    ("money", "money_asked",
     "🚨 ALERT: Money / payment is being demanded. Do NOT send money!"),
    ("transfer money", "money_asked",
     "🚨 ALERT: Money transfer is being demanded. Do NOT transfer money!"),
    (
        "send money",
        "money_asked",
        (
            "🚨 ALERT: Money transfer requested. "
            "Do NOT send money to unknown callers!"
        ),
    ),
    ("payment", "money_asked",
     "🚨 ALERT: Payment is being demanded. Do NOT pay!"),
    # Hindi Devanagari
    ("पैसे", "money_asked",
     "🚨 अलर्ट: पैसे मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("पैसा", "money_asked",
     "🚨 अलर्ट: पैसे मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("रुपये", "money_asked",
     "🚨 अलर्ट: पैसे मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("रुपए", "money_asked",
     "🚨 अलर्ट: पैसे मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("भेजो", "money_asked",
     "🚨 अलर्ट: पैसे भेजने को कहा जा रहा है। ना भेजें!"),
    ("ट्रांसफर", "money_asked",
     "🚨 अलर्ट: ट्रांसफर मांगा जा रहा है। पैसे ना ट्रांसफर करें!"),
    # Hindi transliterated
    ("paisa", "money_asked",
     "🚨 ALERT: Money being demanded. Do NOT send!"),
    ("paise", "money_asked",
     "🚨 ALERT: Money being demanded. Do NOT send!"),
    ("rupaye", "money_asked",
     "🚨 ALERT: Money being demanded. Do NOT send!"),
    ("bhejo", "money_asked",
     "🚨 ALERT: Money transfer demanded. Do NOT send!"),
    ("paisa bhejo", "money_asked",
     "🚨 ALERT: Money transfer demanded. Do NOT send!"),

    # ── KYC Scam ──────────────────────────────────────────────
    (
        "kyc",
        "kyc_scam",
        (
            "🚨 ALERT: Fake KYC verification detected. "
            "Banks NEVER ask for KYC over phone!"
        ),
    ),
    ("केवाईसी", "kyc_scam",
     "🚨 अलर्ट: फर्जी KYC वेरिफिकेशन। बैंक कभी फोन पर KYC नहीं मांगता!"),

    # ── Bank Details / Card / Aadhaar ─────────────────────────
    # English
    ("cvv", "bank_details_asked",
     "🚨 ALERT: CVV number is being requested. This is a SCAM!"),
    ("credit card", "bank_details_asked",
     "🚨 ALERT: Credit card details being requested. This is likely a SCAM!"),
    ("debit card", "bank_details_asked",
     "🚨 ALERT: Debit card details being requested. This is likely a SCAM!"),
    ("bank account", "bank_details_asked",
     "🚨 ALERT: Bank account details being requested. This is likely a SCAM!"),
    ("account number", "bank_details_asked",
     "🚨 ALERT: Account number being requested. This is likely a SCAM!"),
    ("aadhaar", "bank_details_asked",
     "🚨 ALERT: Aadhaar number is being requested. NEVER share on phone!"),
    ("aadhar", "bank_details_asked",
     "🚨 ALERT: Aadhaar number is being requested. NEVER share on phone!"),
    # Hindi Devanagari
    ("क्रेडिट कार्ड", "bank_details_asked",
     "🚨 अलर्ट: क्रेडिट कार्ड डिटेल्स मांगे जा रहे हैं। यह स्कैम है!"),
    ("डेबिट कार्ड", "bank_details_asked",
     "🚨 अलर्ट: डेबिट कार्ड डिटेल्स मांगे जा रहे हैं। यह स्कैम है!"),
    ("बैंक अकाउंट", "bank_details_asked",
     "🚨 अलर्ट: बैंक अकाउंट डिटेल्स मांगे जा रहे हैं। शेयर न करें!"),
    ("खाता नंबर", "bank_details_asked",
     "🚨 अलर्ट: खाता नंबर मांगा जा रहा है। न बताएं!"),
    ("आधार", "bank_details_asked",
     "🚨 अलर्ट: आधार नंबर मांगा जा रहा है। फोन पर कभी न बताएं!"),
    ("सीवीवी", "bank_details_asked",
     "🚨 अलर्ट: CVV मांगा जा रहा है। यह स्कैम है!"),
]


def classify_scam_alert(text: str) -> tuple[Optional[str], Optional[str]]:
    """
    Check transcript text for scam indicators.

    Returns (alert_type, alert_message) or (None, None) if safe.
    """
    if not text:
        return None, None

    lowered = text.lower()
    for keyword, alert_type, message in _SCAM_ALERT_RULES:
        if keyword in lowered:
            print(f"[SCAM] Alert triggered: {keyword} -> {alert_type}")
            return alert_type, message

    return None, None


class SarvamSTT:
    """Async Sarvam AI speech-to-text client."""

    def __init__(self) -> None:
        self.enabled = SARVAM_ENABLED and bool(SARVAM_API_KEY)
        self._session: Optional[aiohttp.ClientSession] = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=SARVAM_TIMEOUT_SEC + 4)
            )
        return self._session

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=0.5, min=1, max=4),
    )
    async def _post_transcribe(
        self,
        form: aiohttp.FormData,
        headers: dict,
    ) -> str:
        session = await self._get_session()
        async with session.post(
            SARVAM_STT_ENDPOINT,
            data=form,
            headers=headers,
        ) as resp:
            if resp.status != 200:
                body = await resp.text()
                print(f"[STT] Sarvam API error {resp.status}: {body[:200]}")
                if resp.status >= 500 or resp.status == 429:
                    raise Exception(f"Transient error: {resp.status}")
                return ""
            body = await resp.json()
            transcript = str(body.get("transcript", "")).strip()
            print(f"[STT] Transcript: '{transcript}'")
            return transcript

    async def transcribe(
        self,
        pcm_bytes: bytes,
        sample_rate: int = 16000,
        channels: int = 1,
        language: str = "hi-IN",
    ) -> str:
        """
        Transcribe raw PCM-16 audio bytes via Sarvam STT REST API.

        Returns transcribed text, or empty string on failure.
        """
        if not self.enabled or not pcm_bytes:
            print(
                "[STT] Skipped: "
                f"enabled={self.enabled}, bytes={len(pcm_bytes)}"
            )
            return ""

        # Run VAD to skip silent chunks
        if not _has_speech(pcm_bytes, sample_rate):
            print("[STT] Skipped: no speech detected")
            return ""

        try:
            wav_data = _pcm_to_wav(pcm_bytes, sample_rate, channels)
            print(f"[STT] PCM->WAV ok, wav_size={len(wav_data)}")
        except Exception as e:
            print(f"[STT] PCM to WAV conversion failed: {e}")
            return ""

        try:
            form = aiohttp.FormData()
            form.add_field(
                "file",
                wav_data,
                filename="audio.wav",
                content_type="audio/wav",
            )
            form.add_field("language_code", language)
            form.add_field("model", "saaras:v3")
            form.add_field("with_timestamps", "false")

            headers = {
                "api-subscription-key": SARVAM_API_KEY,
            }

            return await self._post_transcribe(form, headers)
        except Exception as e:
            print(f"[STT] Sarvam STT failed after retries: {e}")
            return ""

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None


# Module-level singleton
sarvam_stt = SarvamSTT()
