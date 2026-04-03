Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$pythonExe = Join-Path $root ".venv311\Scripts\python.exe"
$envFile = Join-Path $root ".env"
$pipeline = Join-Path $root "pipeline.py"

if (-not (Test-Path $pythonExe)) {
  throw "Python not found: $pythonExe. Run setup_whisper_kit.ps1 first."
}
if (-not (Test-Path $envFile)) {
  throw "Missing .env at $envFile"
}
if (-not (Test-Path $pipeline)) {
  throw "Missing pipeline.py at $pipeline"
}

Set-Location $root
& $pythonExe $pipeline dev
