Param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $repoRoot "venv\Scripts\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Python executable not found at $pythonExe"
}

Set-Location $PSScriptRoot
& $pythonExe -m uvicorn main:app --host $BindHost --port $Port --reload
