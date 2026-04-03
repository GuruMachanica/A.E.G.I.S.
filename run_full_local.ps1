Param(
  [int]$BackendPort = 8000,
  [int]$SttPort = 8001,
  [switch]$RestartStt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$backendScript = Join-Path $root "start_backend.ps1"
$sttScript = Join-Path $root "backend\app\ml\AEGIS-WHISPER-KIT\run_localhost_stt.ps1"
$healthScript = Join-Path $root "check_backend_health.ps1"

if (-not (Test-Path $backendScript)) { throw "Missing $backendScript" }
if (-not (Test-Path $sttScript)) { throw "Missing $sttScript" }
if (-not (Test-Path $healthScript)) { throw "Missing $healthScript" }

Start-Process powershell -ArgumentList @('-NoExit','-ExecutionPolicy','Bypass','-File', $backendScript, '-Port', $BackendPort)

$sttArgs = @('-NoExit','-ExecutionPolicy','Bypass','-File', $sttScript, '-Port', $SttPort)
if ($RestartStt) {
  $sttArgs += '-KillExisting'
}
Start-Process powershell -ArgumentList $sttArgs

Start-Sleep -Seconds 2
powershell -ExecutionPolicy Bypass -File $healthScript -Port $BackendPort

Write-Host ""
Write-Host "Backend URL: http://127.0.0.1:$BackendPort"
Write-Host "STT UI URL:  http://127.0.0.1:$SttPort"
Write-Host ""
Write-Host "If STT port is busy, re-run with:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\run_full_local.ps1 -SttPort 8002 -RestartStt"
