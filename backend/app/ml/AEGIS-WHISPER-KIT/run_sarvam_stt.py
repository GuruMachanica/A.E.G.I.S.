"""
AEGIS - Sarvam AI STT + Scam Detection (Standalone Mic Capture)

Captures live microphone audio, sends 4-second chunks to Sarvam AI
Speech-to-Text API, and runs scam detection on the transcripts.

Usage:
  .venv311\Scripts\python.exe run_sarvam_stt.py
"""

import asyncio
import io
import json
import os
import struct
import sys
import wave
from datetime import datetime

import aiohttp
import sounddevice as sd
from dotenv import load_dotenv

load_dotenv()

# ── Config ──────────────────────────────────────────────────────────────────────
SARVAM_API_KEY = os.getenv("SARVAM_API_KEY", "")
SARVAM_STT_ENDPOINT = "https://api.sarvam.ai/speech-to-text"
SAMPLE_RATE = 16000
CHANNELS = 1
CHUNK_DURATION_SEC = 4  # Send audio every 4 seconds
LANGUAGE = "hi-IN"      # Hindi-India (supports 22 Indian languages)

# ── Scam Detection Rules ────────────────────────────────────────────────────────
SCAM_RULES = [
    ("otp",              "🔑 OTP SCAM",       "Someone is asking for your OTP / verification code. NEVER share your OTP!"),
    ("verification code","🔑 OTP SCAM",       "Someone is asking for your verification code. NEVER share it!"),
    ("pin",              "🔑 PIN SCAM",        "Someone is asking for your PIN. NEVER share your PIN with anyone!"),
    ("upi pin",          "🔑 UPI PIN SCAM",    "Someone is asking for your UPI PIN. Banks NEVER ask for UPI PIN!"),
    ("cvv",              "🏦 CVV SCAM",        "CVV number is being requested. This is a SCAM!"),
    ("money",            "💰 MONEY DEMAND",    "Money / payment is being demanded. Do NOT send money!"),
    ("transfer money",   "💰 MONEY TRANSFER",  "Money transfer is being demanded. Do NOT transfer!"),
    ("send money",       "💰 MONEY TRANSFER",  "Money transfer requested. Do NOT send money to unknown callers!"),
    ("पैसे",             "💰 पैसे की मांग",     "पैसे मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("रुपये",            "💰 रुपये की मांग",    "रुपये मांगे जा रहे हैं। पैसे ना भेजें!"),
    ("kyc",              "📋 FAKE KYC",        "Fake KYC verification detected. Banks NEVER ask for KYC over phone!"),
    ("credit card",      "🏦 CARD SCAM",       "Credit card details being requested. This is likely a SCAM!"),
    ("bank account",     "🏦 BANK SCAM",       "Bank account details being requested. This is likely a SCAM!"),
    ("aadhaar",          "🔐 AADHAAR SCAM",    "Aadhaar number is being requested. NEVER share on phone!"),
    ("password",         "🔑 PASSWORD SCAM",   "Your password is being asked for. NEVER share passwords!"),
    ("urgent",           "⚠️  URGENCY TACTIC",  "Urgency tactic detected — scammers use pressure to rush you!"),
    ("तुरंत",            "⚠️  जल्दबाजी",        "तुरंत करने को कहा जा रहा है — यह स्कैम हो सकता है!"),
]


def check_scam(text: str) -> list[tuple[str, str]]:
    """Check transcript for scam keywords. Returns list of (label, message)."""
    if not text:
        return []
    lowered = text.lower()
    alerts = []
    seen_labels = set()
    for keyword, label, message in SCAM_RULES:
        if keyword in lowered and label not in seen_labels:
            alerts.append((label, message))
            seen_labels.add(label)
    return alerts


def pcm_to_wav(pcm_bytes: bytes, sample_rate: int = 16000, channels: int = 1) -> bytes:
    """Convert raw PCM-16 LE bytes into WAV format in memory."""
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit = 2 bytes
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    buf.seek(0)
    return buf.read()


async def transcribe_audio(session: aiohttp.ClientSession, wav_data: bytes) -> str:
    """Send WAV audio to Sarvam STT API and return transcript."""
    form = aiohttp.FormData()
    form.add_field("file", wav_data, filename="audio.wav", content_type="audio/wav")
    form.add_field("language_code", LANGUAGE)
    form.add_field("model", "saaras:v3")
    form.add_field("with_timestamps", "false")

    headers = {
        "api-subscription-key": SARVAM_API_KEY,
    }

    try:
        async with session.post(SARVAM_STT_ENDPOINT, data=form, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
            if resp.status != 200:
                error_text = await resp.text()
                print(f"  ❌ Sarvam API error ({resp.status}): {error_text[:200]}")
                return ""
            body = await resp.json()
            return str(body.get("transcript", "")).strip()
    except asyncio.TimeoutError:
        print("  ⏱️  Sarvam API timeout")
        return ""
    except Exception as e:
        print(f"  ❌ Sarvam API error: {e}")
        return ""


async def main():
    if not SARVAM_API_KEY:
        print("❌ SARVAM_API_KEY not set in .env file!")
        sys.exit(1)

    print()
    print("=" * 70)
    print("  🛡️  A.E.G.I.S. — Sarvam AI Speech-to-Text + Scam Detection")
    print("=" * 70)
    print(f"  📡 STT Model  : saaras:v3")
    print(f"  🌐 Language   : {LANGUAGE}")
    print(f"  🎤 Sample Rate: {SAMPLE_RATE} Hz")
    print(f"  ⏱️  Chunk Size : {CHUNK_DURATION_SEC}s")
    print(f"  🔑 API Key    : {SARVAM_API_KEY[:12]}...")
    print("=" * 70)
    print()
    print("  🎙️  Listening... Speak now! (Press Ctrl+C to stop)")
    print()

    # Audio buffer
    audio_buffer = bytearray()
    transcript_history: list[str] = []
    chunk_count = 0

    def audio_callback(indata, frames, time_info, status):
        nonlocal audio_buffer
        if status:
            pass  # skip status messages
        # indata is float32, convert to int16 PCM
        pcm = (indata * 32767).astype('int16').tobytes()
        audio_buffer.extend(pcm)

    # Open microphone stream
    stream = sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=CHANNELS,
        dtype='float32',
        blocksize=int(SAMPLE_RATE * 0.5),  # 500ms blocks
        callback=audio_callback,
    )

    async with aiohttp.ClientSession() as session:
        stream.start()
        try:
            while True:
                # Wait for enough audio
                await asyncio.sleep(CHUNK_DURATION_SEC)

                # Grab accumulated audio
                if len(audio_buffer) == 0:
                    continue

                chunk_bytes = bytes(audio_buffer)
                audio_buffer.clear()
                chunk_count += 1

                # Convert to WAV
                wav_data = pcm_to_wav(chunk_bytes, SAMPLE_RATE, CHANNELS)

                timestamp = datetime.now().strftime("%H:%M:%S")
                print(f"  [{timestamp}] 📤 Sending chunk #{chunk_count} ({len(chunk_bytes)//2} samples, {len(chunk_bytes)/(SAMPLE_RATE*2):.1f}s)...")

                # Transcribe via Sarvam AI
                transcript = await transcribe_audio(session, wav_data)

                if transcript:
                    transcript_history.append(transcript)
                    print(f"  [{timestamp}] 🎤 Transcript: \"{transcript}\"")

                    # Check for scam patterns
                    alerts = check_scam(transcript)
                    if alerts:
                        print()
                        print("  " + "🚨" * 30)
                        for label, message in alerts:
                            print(f"  🚨 {label}: {message}")
                        print("  " + "🚨" * 30)
                        print()
                    else:
                        print(f"  [{timestamp}] ✅ No scam detected — conversation appears safe")
                else:
                    print(f"  [{timestamp}] 🔇 (no speech detected)")

                print()

        except KeyboardInterrupt:
            print()
            print("=" * 70)
            print("  ⏹️  Stopped listening.")
            print(f"  📊 Total chunks processed: {chunk_count}")
            print(f"  📝 Full transcript:")
            if transcript_history:
                print(f"     {' '.join(transcript_history)}")
            else:
                print(f"     (no speech captured)")
            print("=" * 70)
        finally:
            stream.stop()
            stream.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
