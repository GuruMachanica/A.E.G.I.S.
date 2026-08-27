# 🛡️ A.E.G.I.S — Total Communication Security

[![CI Pipeline](https://github.com/GuruMachanica/A.E.G.I.S./actions/workflows/ci.yml/badge.svg)](https://github.com/GuruMachanica/A.E.G.I.S./actions)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.116+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.2+-EE4C2C?logo=pytorch&logoColor=white)](https://pytorch.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-Proprietary%20Strict%20Inspection%20Only-red.svg)](LICENSE)

**A.E.G.I.S** (*Automated Evaluation & Governance Intelligence System*) is an enterprise-grade, real-time communication defense platform designed to detect **deepfake synthetic voice impersonation**, **social engineering scams**, and **pre-call spoofing threats** during live audio phone calls.

---

## 🌟 Key Capabilities

* **🎙️ Deepfake Synthetic Voice Defense**: Real-time acoustic inference powered by **AASIST** (*Audio Anti-Spoofing using Integrated Spectro-Temporal Graph Neural Networks*) on raw 16 kHz waveforms.
* **🧠 Real-time Multilingual Threat Intelligence**: Live transcription via **Sarvam AI STT** and contextual threat detection covering **Hindi, English, Tamil, Telugu, Bengali, Marathi, and Kannada** for OTP theft, KYC panic traps, and digital arrest threats.
* **📞 Pre-Call Caller Reputation Scanner**: Prefix analysis and spam pattern matching against international callback traps, spoofed ranges, and unregistered telemarketing prefixes.
* **🚨 Guardian Emergency SOS Dispatch**: Automated high-priority email alert dispatch to emergency contacts/guardians when critical scam risk (>85%) is confirmed during a call.
* **⚡ High-Throughput Async Pipeline**: Zero-block async WebSocket audio streaming with dynamic WebRTC Voice Activity Detection (VAD) and sliding ring-buffer chunking.
* **📑 Automated Forensic PDF Reports**: Automated generation of cryptographic call analysis threat reports with full transcription, acoustic anomalies, and safety advisories via ReportLab.
* **🔐 Secure Authentication & 2FA**: RFC 7518 compliant JWT token lifecycle, refresh token rotation, PBKDF2 password hashing, and rate-limited email OTP challenge verification.
* **📱 Modern Cross-Platform Flutter App**: Real-time waveform visualizer, risk radar gauges, dynamic threat alert banners, and local call record synchronization using Flutter Riverpod.

---

## 🏗️ Architecture Overview

```
+-----------------------------------------------------------------------------------+
|                               A.E.G.I.S PLATFORM                                  |
+-----------------------------------------------------------------------------------+
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
      ┌─────────────────────┐                         ┌─────────────────────┐
      │ Flutter Mobile App  │                         │  FastAPI Backend    │
      │  (Riverpod Client)  │◄── WebSocket / REST ───►│   (Service Layer)   │
      └─────────────────────┘                         └─────────────────────┘
                 │                                               │
                 │ 16kHz PCM Stream                              ├── Audio VAD Chunker
                 ▼                                               ├── Sarvam STT Engine
      ┌─────────────────────┐                                    ├── AASIST PyTorch ML
      │   Microphone &      │                                    ├── NLP Risk Engine
      │   Foreground Audio  │                                    ├── Phone Lookup Engine
      └─────────────────────┘                                    ├── Guardian SOS Alert
                                                                 └── PDF Report Gen
                                                                         │
                                                                         ▼
                                                              ┌─────────────────────┐
                                                              │  SQLite (WAL Mode)  │
                                                              └─────────────────────┘
```

---

## 📁 Repository Structure

```
A.E.G.I.S/
├── .github/workflows/
│   └── ci.yml                     # Automated GitHub Actions Pytest CI workflow
│
├── aegis_app/                     # Flutter Cross-Platform Mobile Client
│   ├── lib/
│   │   ├── core/                  # Color tokens, constants, theme
│   │   ├── models/                # CallRecord, RiskLevel data models
│   │   ├── providers/             # Riverpod state notifiers (Auth, History, Monitor)
│   │   ├── screens/               # Live monitor, history, profile, welcome
│   │   ├── services/              # Backend HTTP & WebSocket streaming client
│   │   └── widgets/               # UI components, risk gauge, threat banners
│   └── pubspec.yaml
│
├── backend/                       # Modernized FastAPI Backend
│   ├── app/
│   │   ├── api/                   # REST & WebSocket Endpoints (Auth, Calls, Reports, Health)
│   │   ├── core/                  # Config, Security, Context-managed SQLite WAL Database
│   │   ├── ml/                    # Self-contained AASIST PyTorch Runner & Graph Model
│   │   ├── schemas/               # Typed Pydantic v2 Request/Response Models
│   │   ├── services/              # Audio Chunker, STT, Risk Engine, Phone Lookup, SOS, PDF Gen
│   │   └── create_app.py          # FastAPI Application Factory & Lifespan Hooks
│   ├── tests/                     # Automated Pytest Suite (18 unit & integration tests)
│   ├── requirements.txt
│   ├── .env.example
│   └── main.py
│
├── .gitignore                     # Comprehensive gitignore for media & caches
├── LICENSE                        # Proprietary Strict Private Use & Inspection License
└── README.md                      # Platform documentation
```

---

## 🔌 API Endpoints Summary

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/health` | Backend and ML engine health check |
| `GET` | `/assist/models/status` | AASIST PyTorch device and model status |
| `GET` | `/assist/lookup/{phone_number}` | Pre-call phone reputation, spam markers & carrier risk |
| `POST` | `/assist/emergency/trigger` | Dispatches Guardian SOS fraud alerts to emergency contacts |
| `WS` | `/assist/live-audio` | Real-time live PCM streaming & threat scoring WebSocket |
| `POST` | `/assist/live-call/start` | Initiates a live call session |
| `POST` | `/assist/live-call/chunk` | Streams PCM chunk and evaluates hybrid threat |
| `POST` | `/assist/live-call/end` | Finalizes call and records summary in DB |
| `GET` | `/assist/report/{call_id}/pdf` | Generates downloadable forensic PDF analysis report |
| `POST` | `/auth/register` | Registers new user account with hashed password |
| `POST` | `/auth/login` | Authenticates user and issues JWT & refresh tokens |
| `POST` | `/auth/login/verify-otp` | Verifies 2FA email challenge |
| `POST` | `/records/sync` | Synchronizes mobile call records with backend |

---

## 🚀 Getting Started

### Prerequisites
* **Python 3.10+** (Tested on Python 3.11 & 3.12)
* **Flutter SDK 3.11+**
* **PowerShell 7+ / Bash**

---

### 1️⃣ Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create & activate virtual environment
python -m venv venv
# On Windows:
.\venv\Scripts\Activate.ps1
# On Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
copy .env.example .env
```

Edit `.env` and set your credentials:
```ini
JWT_SECRET=your-secure-32-char-jwt-secret-key
SARVAM_API_KEY=your-sarvam-ai-key-if-enabled
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

#### Run the Backend Server:
```bash
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
Interactive Swagger Documentation is available at: `http://127.0.0.1:8000/docs`

---

### 2️⃣ Run Automated Tests

The repository includes a full automated `pytest` test suite:

```bash
pytest tests/ -v
```

Output:
```
tests/test_api_endpoints.py::test_health_check PASSED                    [  5%]
tests/test_api_endpoints.py::test_model_status PASSED                    [ 11%]
tests/test_api_endpoints.py::test_user_registration_and_login_flow PASSED [ 16%]
tests/test_api_endpoints.py::test_live_call_http_lifecycle PASSED        [ 22%]
tests/test_audio.py::test_calculate_audio_rms_silence PASSED             [ 27%]
tests/test_audio.py::test_calculate_audio_rms_sine PASSED                [ 33%]
tests/test_audio.py::test_pcm_to_wav_conversion PASSED                   [ 38%]
tests/test_audio.py::test_slice_pcm_windows PASSED                       [ 44%]
tests/test_emergency_service.py::test_emergency_alert_dispatch_skipped_invalid_email PASSED [ 50%]
tests/test_emergency_service.py::test_emergency_alert_dispatch_valid_payload PASSED [ 55%]
tests/test_lookup_service.py::test_analyze_valid_clean_number PASSED     [ 61%]
tests/test_lookup_service.py::test_analyze_suspicious_prefix PASSED      [ 66%]
tests/test_lookup_service.py::test_analyze_telemarketer_pattern PASSED   [ 72%]
tests/test_lookup_service.py::test_analyze_empty_number PASSED           [ 77%]
tests/test_report_service.py::test_generate_call_report_pdf PASSED       [ 83%]
tests/test_risk_engine.py::test_keyword_extraction_otp PASSED            [ 88%]
tests/test_risk_engine.py::test_intent_risk_scoring PASSED               [ 94%]
tests/test_risk_engine.py::test_hybrid_risk_fusion PASSED                [100%]

======================== 18 passed in 8.65s (100%) ========================
```

---

### 3️⃣ Mobile Client Setup (Flutter)

```bash
cd aegis_app

# Install Flutter packages
flutter pub get

# Run on connected device / emulator
flutter run
```

---

## 🔒 Security & Compliance

* **Zero Plaintext Secrets**: All sensitive API keys and SMTP credentials are strictly loaded via `.env` and guarded by `.gitignore`.
* **Safe Model Weights**: All PyTorch checkpoints are validated with `weights_only=True` to eliminate arbitrary code execution.
* **Database Isolation**: SQLite runs in WAL mode with connection pooling and query parameterization to prevent SQL injection and file locks.

---

## 📄 License

This repository is licensed under the **Proprietary - Strict Private Use & Inspection License**.  
See the [LICENSE](LICENSE) file for the full legally binding terms and restrictions.

**Copyright (c) 2026 Team Ironlogic. All rights reserved.**
