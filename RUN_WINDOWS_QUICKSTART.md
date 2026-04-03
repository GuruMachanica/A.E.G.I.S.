# Windows Quick Start (AEGIS)

## 1) Start backend from project root

```powershell
powershell -ExecutionPolicy Bypass -File .\start_backend.ps1
```

## 2) In another terminal, verify health

```powershell
powershell -ExecutionPolicy Bypass -File .\check_backend_health.ps1
```

You should see valid JSON for `/health` and `/assist/status`.

## 3) Common mistakes to avoid

- Do not run `uvicorn main:app` from project root.
- Do not run `.python.exe`; use `python` or full path.
- If port `8000` is busy, start with another port:

```powershell
powershell -ExecutionPolicy Bypass -File .\start_backend.ps1 -Port 8001
powershell -ExecutionPolicy Bypass -File .\check_backend_health.ps1 -Port 8001
```
