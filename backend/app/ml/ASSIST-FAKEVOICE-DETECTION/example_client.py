import asyncio
import json
import soundfile as sf
import websockets


async def stream_file(path, uri="ws://localhost:8000/ws", chunk_ms=200):
    data, sr = sf.read(path, dtype="int16")
    if data.ndim > 1:
        # mix to mono
        data = data.mean(axis=1).astype("int16")

    # send metadata first
    async with websockets.connect(uri) as ws:
        meta = {"type": "meta", "meta": {"sample_rate": sr, "channels": 1, "format": "int16"}}
        await ws.send(json.dumps(meta))

        # chunk size in samples
        chunk_samps = int(sr * (chunk_ms / 1000.0))
        pos = 0
        while pos < len(data):
            chunk = data[pos : pos + chunk_samps]
            await ws.send(chunk.tobytes())
            pos += chunk_samps
            # optional small delay to simulate streaming
            await asyncio.sleep(chunk_ms / 1000.0)

        # Signal end-of-stream so the server raises WebSocketDisconnect and closes
        await ws.close()

        # Drain any remaining responses already buffered
        try:
            while True:
                resp = await ws.recv()
                print("SERVER:", resp)
        except Exception:
            pass


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python example_client.py path/to/file.wav")
        sys.exit(1)

    path = sys.argv[1]
    asyncio.run(stream_file(path))
