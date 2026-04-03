# A.E.G.I.S Backend — Free-Tier Deployment

This setup runs your backend on free infrastructure using Docker.

## Recommended free hosting options

- Oracle Cloud Always Free VM (best for always-on backend)
- Fly.io free allowances (smaller workloads)
- Render free web service (may sleep)

For stable realtime WebSocket behavior, Oracle VM is recommended.

## Stack in this repo

- `FastAPI + Uvicorn`
- `SQLite` persisted to Docker volume
- `Caddy` reverse proxy (HTTP/HTTPS + WebSocket passthrough)
- `ASSIST` model loaded from repo path

## 1) Prepare server

On Ubuntu VM:

```bash
chmod +x deploy/oracle/setup_vm.sh
./deploy/oracle/setup_vm.sh
```

Log out and log in again.

## 2) Clone and configure

```bash
git clone <your-repo-url>
cd Aegis_Mobile_App/backend
cp .env.example .env
```

Edit `.env` and set strong secrets:

- `JWT_SECRET`
- `REFRESH_SECRET`
- `OTP_PEPPER`

Set domain mode:

- Local HTTP only: `AEGIS_DOMAIN=:80`
- Real domain with HTTPS: `AEGIS_DOMAIN=api.yourdomain.com`

If using real domain, point DNS `A` record to the VM IP.

## 3) Start backend

```bash
chmod +x deploy/oracle/deploy_backend.sh
./deploy/oracle/deploy_backend.sh
```

## 4) Verify

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/assist/status
```

If behind Caddy on port 80/443:

```bash
curl http://<your-domain>/health
curl http://<your-domain>/assist/status
```

## 5) Update Flutter app to use deployed backend

Build with runtime defines:

```bash
flutter run \
  --dart-define=AEGIS_API_BASE_URL=https://api.yourdomain.com \
  --dart-define=AEGIS_WS_URL=wss://api.yourdomain.com/assist/live-audio
```

## Optional: Cloudflare Tunnel (free)

Use this when you want HTTPS + domain without opening server ports.

1. Create tunnel and credentials on server (cloudflared CLI).
2. Copy config template:

```bash
cp deploy/cloudflare/cloudflared-config.yml.example deploy/cloudflare/cloudflared-config.yml
```

3. Put your tunnel credentials JSON into `deploy/cloudflare/credentials/`.
4. Start tunnel stack:

```bash
docker compose -f docker-compose.cloudflare.yml up -d --build
```

For HTTP-only local/test:

```bash
flutter run \
  --dart-define=AEGIS_API_BASE_URL=http://<server-ip>:8000 \
  --dart-define=AEGIS_WS_URL=ws://<server-ip>:8000/assist/live-audio
```

## Notes

- `SQLite` is fine for initial free-tier production and small traffic.
- For growth, migrate to free Postgres tier (Supabase/Neon) while keeping the same app API.
- Keep `workers=1` for SQLite safety in this setup.

## Local run (Windows, from workspace root)

Use the helper script so `main.py` resolves correctly:

```powershell
./backend/run_backend.ps1
```
