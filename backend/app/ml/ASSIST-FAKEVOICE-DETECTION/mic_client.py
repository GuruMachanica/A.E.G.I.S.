"""
Live microphone streaming client for AEGIS.

Records from the default microphone and streams PCM int16 audio to the
AEGIS WebSocket server in real time, printing deepfake detection results.

Usage:
    python mic_client.py [--uri ws://localhost:8000/ws] [--duration 30]

Requirements:
    pip install pyaudio
"""

import argparse
import asyncio
import json
import threading
import queue
import sys

import websockets

SAMPLE_RATE = 16000      # Hz — matches AASIST's expected input rate directly
CHANNELS = 1
FORMAT_BYTES = 2         # int16 = 2 bytes per sample
CHUNK_MS = 200           # how many ms of audio per send chunk
CHUNK_FRAMES = int(SAMPLE_RATE * CHUNK_MS / 1000)  # samples per chunk


def _mic_thread(audio_queue: queue.Queue, stop_event: threading.Event, duration: float):
    """Capture mic audio in a background thread and push chunks onto the queue."""
    try:
        import pyaudio
    except ImportError:
        print("ERROR: pyaudio is not installed. Run:  .venv\\Scripts\\pip install pyaudio")
        stop_event.set()
        return

    pa = pyaudio.PyAudio()
    stream = pa.open(
        format=pyaudio.paInt16,
        channels=CHANNELS,
        rate=SAMPLE_RATE,
        input=True,
        frames_per_buffer=CHUNK_FRAMES,
    )

    print(f"🎙  Recording for {duration}s at {SAMPLE_RATE} Hz — speak now...")
    captured = 0.0
    while not stop_event.is_set() and captured < duration:
        data = stream.read(CHUNK_FRAMES, exception_on_overflow=False)
        audio_queue.put(data)
        captured += CHUNK_MS / 1000.0

    stream.stop_stream()
    stream.close()
    pa.terminate()
    audio_queue.put(None)  # sentinel


async def stream_mic(uri: str, duration: float):
    audio_queue: queue.Queue = queue.Queue()
    stop_event = threading.Event()

    # Start mic capture in a background thread
    t = threading.Thread(target=_mic_thread, args=(audio_queue, stop_event, duration), daemon=True)
    t.start()

    async with websockets.connect(uri) as ws:
        # Send metadata first
        meta = {
            "type": "meta",
            "meta": {"sample_rate": SAMPLE_RATE, "channels": CHANNELS, "format": "int16"},
        }
        await ws.send(json.dumps(meta))

        # Receive metadata acknowledgement
        ack = await ws.recv()
        print("SERVER:", ack)

        # Stream mic chunks; collect server responses concurrently
        async def send_loop():
            loop = asyncio.get_event_loop()
            while True:
                chunk = await loop.run_in_executor(None, audio_queue.get)
                if chunk is None:
                    break
                await ws.send(chunk)
            await ws.close()

        async def recv_loop():
            try:
                async for msg in ws:
                    data = json.loads(msg)
                    prob = data.get("synthetic_probability", 0)
                    alert = data.get("alert", "")
                    bar = "█" * int(prob * 20)
                    print(f"  synthetic={prob:.4f} [{bar:<20}]  → {alert}")
            except Exception:
                pass

        await asyncio.gather(send_loop(), recv_loop())

    stop_event.set()
    t.join()
    print("Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Stream microphone to AEGIS deepfake detector")
    parser.add_argument("--uri", default="ws://localhost:8000/ws", help="WebSocket URI")
    parser.add_argument("--duration", type=float, default=30.0, help="Seconds to record (default 30)")
    args = parser.parse_args()

    asyncio.run(stream_mic(args.uri, args.duration))
