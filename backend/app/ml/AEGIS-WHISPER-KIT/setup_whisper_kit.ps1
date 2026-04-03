Param(
  [string]$VenvDir = ".venv311"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$venvPath = Join-Path $scriptRoot $VenvDir

Write-Host "[1/7] Detecting Python 3.11..."
$pythonCmd = $null

if (Get-Command py -ErrorAction SilentlyContinue) {
  try {
    $null = & py -3.11 -c "import sys; print(sys.version)" 2>$null
    if ($LASTEXITCODE -eq 0) {
      $pythonCmd = "py -3.11"
    }
  } catch {
  }
}

if (-not $pythonCmd -and (Get-Command python -ErrorAction SilentlyContinue)) {
  try {
    $ver = (& python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null).Trim()
    if ($ver -eq "3.11") {
      $pythonCmd = "python"
    }
  } catch {
  }
}

if (-not $pythonCmd) {
  Write-Host "Python 3.11 not found." -ForegroundColor Yellow
  Write-Host "Install Python 3.11 first, then re-run this script." -ForegroundColor Yellow
  Write-Host "Download: https://www.python.org/downloads/release/python-3119/"
  exit 1
}

Write-Host "[2/7] Creating virtual environment: $VenvDir"
if ($pythonCmd -eq "py -3.11") {
  & py -3.11 -m venv $venvPath
} else {
  & python -m venv $venvPath
}

$pythonExe = Join-Path $venvPath "Scripts\python.exe"
$pipExe = Join-Path $venvPath "Scripts\pip.exe"

Write-Host "[3/7] Upgrading pip/setuptools/wheel..."
& $pythonExe -m pip install --upgrade pip setuptools wheel

Write-Host "[4/7] Installing runtime dependencies..."
& $pipExe install python-dotenv livekit-api livekit-agents livekit-plugins-openai livekit-plugins-sarvam

Write-Host "[5/7] Installing WhisperLiveKit (editable, CPU profile)..."
Set-Location (Join-Path $scriptRoot "WhisperLiveKit")
& $pipExe install -e ".[cpu]"
Set-Location $scriptRoot

Write-Host "[6/7] Preparing .env from template..."
if (-not (Test-Path ".env")) {
  Copy-Item (Join-Path $scriptRoot ".env.example") (Join-Path $scriptRoot ".env")
}

Write-Host "[7/7] Done. Next steps:"
Write-Host "  1) Edit .env and set LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET, SARVAM_API_KEY"
Write-Host "  2) Run LiveKit mode: powershell -ExecutionPolicy Bypass -File .\run_livekit_agent.ps1"
Write-Host "  3) Run localhost mode: powershell -ExecutionPolicy Bypass -File .\run_localhost_stt.ps1"
