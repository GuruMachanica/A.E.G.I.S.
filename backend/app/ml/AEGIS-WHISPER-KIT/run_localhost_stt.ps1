Param(
  [int]$Port = 8001,
  [string]$BindHost = "0.0.0.0",
  [string]$Model = "tiny",
  [string]$Language = "hi",
  [string]$BackendPolicy = "localagreement",
  [string]$Backend = "faster-whisper",
  [double]$MinChunkSize = 0.4,
  [double]$AudioMaxLen = 8.0,
  [double]$AudioMinLen = 0.4,
  [switch]$UseVac,
  [switch]$KillExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$pythonExe = Join-Path $root ".venv311\Scripts\python.exe"
$wlkDir = Join-Path $root "WhisperLiveKit"

if (-not (Test-Path $pythonExe)) {
  throw "Python not found: $pythonExe. Run setup_whisper_kit.ps1 first."
}
if (-not (Test-Path $wlkDir)) {
  throw "WhisperLiveKit directory not found: $wlkDir"
}

$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($existing) {
  $ownerPid = $existing.OwningProcess
  if ($KillExisting) {
    Stop-Process -Id $ownerPid -Force
    Start-Sleep -Milliseconds 400
  } else {
    throw "Port $Port is already in use by PID $ownerPid on $($existing.LocalAddress). Use -KillExisting or choose another -Port."
  }
}

Set-Location $wlkDir
$args = @(
  "-m", "whisperlivekit.basic_server",
  "--host", "$BindHost",
  "--port", "$Port",
  "--model", "$Model",
  "--language", "$Language",
  "--backend-policy", "$BackendPolicy",
  "--backend", "$Backend",
  "--pcm-input",
  "--min-chunk-size", "$MinChunkSize",
  "--audio-max-len", "$AudioMaxLen",
  "--audio-min-len", "$AudioMinLen",
  "--beams", "1"
)

if (-not $UseVac) {
  $args += "--no-vac"
}

& $pythonExe @args
