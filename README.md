# 🛡️ A.E.G.I.S — Total Communication Security

[![FastAPI](https://img.shields.io/badge/FastAPI-0.116+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.2+-EE4C2C?logo=pytorch&logoColor=white)](https://pytorch.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-Proprietary%20Strict%20Inspection%20Only-red.svg)](LICENSE)

**A.E.G.I.S** (*Automated Evaluation & Governance Intelligence System*) is an enterprise-grade, real-time communication defense platform designed to detect **deepfake voice impersonation** and **social engineering scams** during live audio phone calls.

---

## 🌟 Key Capabilities

* **🎙️ Deepfake Synthetic Voice Defense**: Real-time acoustic inference powered by **AASIST** (*Audio Anti-Spoofing using Integrated Spectro-Temporal Graph Neural Networks*) on raw 16 kHz waveforms.
* **🧠 Real-time Multilingual NLP Threat Intelligence**: Live transcription via **Sarvam AI STT** and regex-driven contextual intent scanning for OTP theft, KYC panic traps, digital arrest threats, and financial fraud across English, Hindi, and Hinglish.
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
      │   Foreground Audio  │                                    └── PDF Report Gen
      └─────────────────────┘                                            │
                                                                         ▼
                                                              ┌─────────────────────┐
                                                              │  SQLite (WAL Mode)  │
                                                              └─────────────────────┘
```

---

## 📁 Repository Structure

```
A.E.G.I.S/
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
│   │   ├── api/                   # REST & WebSocket Route Handlers (Auth, Calls, Reports)
│   │   ├── core/                  # Config, Security, Context-managed SQLite WAL Database
│   │   ├── ml/                    # Self-contained AASIST PyTorch Runner & Graph Model
│   │   ├── schemas/               # Typed Pydantic v2 Request/Response Models
│   │   ├── services/              # Audio Chunker, Sarvam STT, Risk Engine, PDF Service
│   │   └── create_app.py          # FastAPI Application Factory & Lifespan Hooks
│   ├── tests/                     # Automated Pytest Suite (12 unit & integration tests)
│   ├── requirements.txt
│   ├── .env.example
│   └── main.py
│
├── .gitignore                     # Comprehensive gitignore for media & caches
├── LICENSE                        # Inspiration-Only License
└── README.md                      # Platform documentation
```

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
API Documentation will be available at: `http://127.0.0.1:8000/docs`

---

### 2️⃣ Run Automated Tests

The repository includes a comprehensive `pytest` test suite:

```bash
pytest tests/ -v
```

Output:
```
tests/test_api_endpoints.py::test_health_check PASSED                    [  8%]
tests/test_api_endpoints.py::test_model_status PASSED                    [ 16%]
tests/test_api_endpoints.py::test_user_registration_and_login_flow PASSED [ 25%]
tests/test_api_endpoints.py::test_live_call_http_lifecycle PASSED        [ 33%]
tests/test_audio.py::test_calculate_audio_rms_silence PASSED             [ 41%]
tests/test_audio.py::test_calculate_audio_rms_sine PASSED                [ 50%]
tests/test_audio.py::test_pcm_to_wav_conversion PASSED                   [ 58%]
tests/test_audio.py::test_slice_pcm_windows PASSED                       [ 66%]
tests/test_report_service.py::test_generate_call_report_pdf PASSED       [ 75%]
tests/test_risk_engine.py::test_keyword_extraction_otp PASSED            [ 83%]
tests/test_risk_engine.py::test_intent_risk_scoring PASSED               [ 91%]
tests/test_risk_engine.py::test_hybrid_risk_fusion PASSED                [100%]

======================== 12 passed in 2.77s ========================
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
