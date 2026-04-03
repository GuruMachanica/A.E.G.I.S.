import json
import os
import time
import uuid
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

import soundfile as sf

from audio_processing import process_buffer_to_windows
from auth import register_auth
from model import AASISTWrapper, DecisionEngine

app = FastAPI()
register_auth(app)

model = AASISTWrapper()
decision = DecisionEngine()

# Local persistence directories
BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data")
WAV_DIR = os.path.join(DATA_DIR, "wavs")
LOG_PATH = os.path.join(DATA_DIR, "inference_log.jsonl")
os.makedirs(WAV_DIR, exist_ok=True)


@app.get("/")
async def root():
    return {"status": "AEGIS backend is running"}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    buffer = bytearray()
    meta = {"sample_rate": 44100, "channels": 1, "format": "int16"}

    try:
        while True:
            data = await websocket.receive()

            if data.get("type") == "websocket.disconnect":
                break

            # Handle text messages (metadata or commands)
            if "text" in data:
                try:
                    msg = json.loads(data["text"]) if data["text"] else {}
                except Exception:
                    msg = {}

                if msg.get("type") == "meta":
                    meta.update(msg.get("meta", {}))
                    await websocket.send_text(json.dumps({"status": "meta_received", "meta": meta}))
                continue

            # Binary frames: append to buffer
            if "bytes" in data and data["bytes"]:
                buffer.extend(data["bytes"])

            # When buffer has at least one full 4s window, process
            windows = process_buffer_to_windows(
                bytes(buffer),
                sample_rate=meta.get("sample_rate", 44100),
                channels=meta.get("channels", 1),
                fmt=meta.get("format", "int16"),
                window_seconds=4,
                target_sr=16000,
            )

            # If windows were produced, trim only consumed bytes from buffer and run inference
            if windows:
                # Each window = window_seconds * sample_rate samples × channels × 2 bytes (int16)
                consumed_bytes = (
                    len(windows)
                    * int(4 * meta.get("sample_rate", 44100))
                    * meta.get("channels", 1)
                    * 2
                )
                buffer = buffer[consumed_bytes:]

                for w in windows:
                    fake_score = model.predict(w, sr=16000)
                    scam_score = 0.0
                    alert = decision.evaluate(fake_score, scam_score)

                    timestamp = time.time()
                    wav_fname = f"{int(timestamp)}_{uuid.uuid4().hex[:8]}.wav"
                    wav_path = os.path.join(WAV_DIR, wav_fname)
                    try:
                        sf.write(wav_path, w, 16000, subtype="PCM_16")
                    except Exception:
                        wav_path = None

                    out = {
                        "timestamp": timestamp,
                        "meta": meta,
                        "synthetic_probability": float(fake_score),
                        "scam_probability": float(scam_score),
                        "alert": alert,
                        "wav_file": os.path.relpath(wav_path, BASE_DIR) if wav_path else None,
                    }

                    # Append to JSONL log
                    try:
                        with open(LOG_PATH, "a", encoding="utf-8") as lf:
                            lf.write(json.dumps(out) + "\n")
                    except Exception:
                        pass

                    await websocket.send_text(json.dumps(out))

    except WebSocketDisconnect:
        return
