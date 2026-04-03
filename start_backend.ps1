Param(
  [int]$Port = 8000,
  [switch]$Reload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$backendDir = Join-Path $repoRoot "backend"
$pythonExe = Join-Path $repoRoot "venv\Scripts\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Python executable not found at $pythonExe"
}
if (-not (Test-Path (Join-Path $backendDir "main.py"))) {
  throw "Backend main.py not found at $backendDir"
}

Set-Location $backendDir
$args = @("-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "$Port")
if ($Reload) {
  $args += "--reload"
}
& $pythonExe @args
