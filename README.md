# AEGIS App Monorepo

AI-assisted anti-scam platform with:
- Flutter mobile client
- FastAPI backend
- STT/voice pipeline under backend ML

## Repository Structure

- aegis_app: Flutter mobile application
- backend: FastAPI backend and ML integration
- backend/app/ml/AEGIS-WHISPER-KIT: Whisper/STT toolkit used by backend flows
- start_backend.ps1: start backend service
- run_full_local.ps1: start backend + STT and run health check

## Prerequisites

- Windows PowerShell
- Python 3.10+
- Flutter SDK (stable)
- Android Studio/SDK (for Android device/emulator)

## Local Setup

### 1) Create Python environment and install backend dependencies

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r .\backend\requirements.txt
```

### 2) Start backend only

```powershell
powershell -ExecutionPolicy Bypass -File .\start_backend.ps1
```

### 3) Start backend + STT together

```powershell
powershell -ExecutionPolicy Bypass -File .\run_full_local.ps1 -BackendPort 8000 -SttPort 8002
```

### 4) Run Flutter mobile app

```powershell
Set-Location .\aegis_app
flutter pub get
powershell -ExecutionPolicy Bypass -File .\run_mobile_app.ps1 -ApiBaseUrl http://127.0.0.1:8000 -SttWsUrl ws://127.0.0.1:8002/asr -Profile
```

## Health Checks

```powershell
powershell -ExecutionPolicy Bypass -File .\check_backend_health.ps1 -Port 8000
```

## GitHub Push Checklist

- Generated folders removed (Flutter build and cache artifacts)
- Python caches removed
- Local database files removed
- Whisper kit moved under backend/app/ml
- Root .gitignore added for reproducible clean commits

## Notes

- Do not commit virtual environments, local databases, or generated build folders.
- If you need a fresh setup, recreate venv and rerun dependency installation.
