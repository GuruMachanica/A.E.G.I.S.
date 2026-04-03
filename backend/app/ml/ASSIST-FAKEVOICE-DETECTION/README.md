# AEGIS Backend — Audio streaming, preprocessing, AASIST wrapper

This scaffold provides:
- FastAPI WebSocket server at `/ws` that accepts PCM `int16` binary frames.
- `audio_processing.py` — resamples to 16kHz, mixes to mono, chunks into 4s windows.
- `model.py` — `AASISTWrapper` (fallback heuristic if AASIST not installed) and `DecisionEngine`.
- `example_client.py` — streams a wav file as PCM `int16` to the server for testing.

Quick start

1. Create a virtualenv and install requirements:

```bash
# delete .venv first if you copied the project from another machine
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

2. Run the server:

```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open `http://localhost:8000` in a browser to verify that the backend is running.
The audio stream endpoint is the WebSocket route `ws://localhost:8000/ws`.

3. Stream a file (example):

```bash
python example_client.py path/to/sample.wav
```

Notes
- If you see a Windows error like `Fatal error in launcher` or `No Python at ...`, the `.venv` was created on a different machine or Python install. Delete `.venv`, recreate it, and reinstall the requirements.
- To use the real AASIST model, install `git+https://github.com/clovaai/aasist.git` and update `model.AASISTWrapper._try_load` to instantiate the AASIST model according to that repo's API.
- This scaffold uses a deterministic fallback heuristic so you can test the full pipeline end-to-end.

## Auth API (Google + JWT + 2FA)

The backend now exposes a production-style auth flow:

1. Client obtains Google `idToken`
2. Client calls `POST /auth/google-login`
3. Backend verifies Google token and returns `access_token` + `refresh_token`
4. Client uses `Authorization: Bearer <access_token>` for protected requests

### Environment variables

Required for production:

- `JWT_SECRET` — strong secret for signing JWTs
- `GOOGLE_CLIENT_ID` — your Google OAuth client ID

Optional:

- `GOOGLE_CLIENT_IDS` — comma-separated audience list if you have multiple apps
- `ACCESS_TOKEN_EXPIRE_MINUTES` (default `15`)
- `REFRESH_TOKEN_EXPIRE_DAYS` (default `30`)
- `OTP_EXPIRE_MINUTES` (default `10`)
- `OTP_LENGTH` (default `6`)
- `SMTP_HOST`, `SMTP_PORT` (default `587`), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_SENDER`
- `DEV_EXPOSE_OTP=true` to include generated OTP in API response (dev only)
- `ALLOW_INSECURE_GOOGLE_TOKEN=true` to allow `dev:<email>:<name>` login tokens (dev only)

### Endpoints

- `POST /auth/google-login`
	- Request: `{ "idToken": "GOOGLE_ID_TOKEN" }`
	- Response: `{ access_token, refresh_token, token_type, expires_in, user }`

- `POST /auth/refresh`
	- Request: `{ "refresh_token": "..." }`
	- Rotates refresh token and returns fresh access + refresh tokens

- `GET /auth/me` (protected)
	- Returns current user profile

- `POST /auth/2fa/start` (protected)
	- Generates OTP and sends via SMTP when configured
	- Falls back to server log output when SMTP is not configured

- `POST /auth/2fa/verify` (protected)
	- Request: `{ "code": "123456" }`
	- Verifies OTP and marks it consumed
