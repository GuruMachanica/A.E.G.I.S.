Param(
  [int]$Port = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$pythonExe = Join-Path $repoRoot "venv\Scripts\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Python executable not found at $pythonExe"
}

$code = @"
import urllib.request
import urllib.error
base = 'http://127.0.0.1:$Port'
for path in ['/health', '/assist/status']:
  url = base + path
  print('GET', url)
  try:
    print(urllib.request.urlopen(url, timeout=8).read().decode())
  except urllib.error.URLError as exc:
    print(f'ERROR: {exc}')
    raise SystemExit(1)
"@

& $pythonExe -c $code
