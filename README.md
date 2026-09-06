# A.E.G.I.S App

## Run

```bash
flutter pub get
flutter run
```

## Local backend integration (Windows)

### 1) Start backend

```bash
cd ../backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Verify backend:

```bash
curl http://127.0.0.1:8000/health
```

### 2) Start Flutter app against local backend

The app now auto-selects local defaults:
- Android emulator: `http://10.0.2.2:8000`
- Windows/Web/iOS simulator: `http://127.0.0.1:8000`

Override explicitly when needed:

```bash
flutter run --dart-define=AEGIS_API_BASE_URL=http://127.0.0.1:8000 --dart-define=AEGIS_WS_URL=ws://127.0.0.1:8000/ws/call-monitor
```

## Production backend configuration

Pass these values with `--dart-define`:

- `AEGIS_API_BASE_URL`
- `AEGIS_WS_URL`
- `AEGIS_GOOGLE_CLIENT_ID`
- `AEGIS_GOOGLE_SERVER_CLIENT_ID`
- `AEGIS_PRIVACY_URL`
- `AEGIS_TERMS_URL`

Example:

```bash
flutter run \
  --dart-define=AEGIS_API_BASE_URL=https://api.example.com \
  --dart-define=AEGIS_WS_URL=wss://api.example.com/ws/call-monitor \
  --dart-define=AEGIS_GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID
```

## Required backend endpoints

- `POST /auth/register`
- `POST /auth/login` (returns pending token + OTP delivery metadata or access token)
- `POST /auth/login/verify-otp`
- `POST /auth/refresh`
- `POST /auth/logout-all`
- `POST /auth/2fa/start`
- `POST /auth/2fa/verify`
- `POST /auth/password/reset-request`
- `PUT /auth/password`
- `GET /profile`
- `PUT /profile`
- `GET /history`
- `POST /history/sync`
- `DELETE /history`

## Release checks

- Test microphone/call monitoring on real devices.
- Test reconnect behavior on network loss.
- Build signed artifacts:
  - `flutter build apk --release`
  - `flutter build appbundle`
- Publish privacy policy and terms URLs.
