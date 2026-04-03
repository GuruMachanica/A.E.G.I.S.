# AEGIS Whisper Kit Setup (Windows)

This repo is cloned and ready, but **runtime setup needs Python 3.11**.

## Why setup failed before

- Current project venv is Python 3.10.
- `WhisperLiveKit/pyproject.toml` requires `>=3.11,<3.14`.

## 1) Install Python 3.11

Install Python 3.11 from python.org and ensure `py -3.11` works.

Verify:

```powershell
py -0p
```

## 2) Run one-command setup

From `AEGIS-WHISPER-KIT` folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_whisper_kit.ps1
```

This will:
- create `.venv311`
- install `WhisperLiveKit` in editable mode with CPU extras
- create `.env` from `.env.example`

## 3) Fill environment values

Edit `.env` and set:
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `SARVAM_API_KEY`

## 4) Run modes

### A) Localhost mode (no LiveKit)

```powershell
powershell -ExecutionPolicy Bypass -File .\run_localhost_stt.ps1
```

This launcher defaults to `--backend-policy localagreement` for better stability on Windows.

If port is already in use:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_localhost_stt.ps1 -Port 8002
```

Or force restart same port:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_localhost_stt.ps1 -Port 8001 -KillExisting
```

Open:

```text
http://127.0.0.1:8001
```

### B) LiveKit agent mode

```powershell
powershell -ExecutionPolicy Bypass -File .\run_livekit_agent.ps1
```

## 5) Optional Vite frontend

```powershell
cd frontend
npm install
npm run dev
```

Note: This frontend requires Node `22.12+` (or `20.19+`). If your Node is older, use localhost mode UI on port `8001`.

## 6) Connect with AEGIS backend

Your AEGIS backend now supports transcript-driven intent fusion in `/assist/live-audio`.
The Whisper pipeline should publish transcript events continuously; your backend consumes transcript events in realtime for risk scoring.

## 7) One-command local run

From workspace root:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_full_local.ps1
```

This starts:
- backend on `127.0.0.1:8000`
- STT UI on `127.0.0.1:8001`

If you want full bridge wiring (LiveKit event -> direct AEGIS websocket feed), add a small adapter process next.
