Param(
  [string]$DeviceId = "GIGYA6ZXGYCAKNKJ",
  [string]$ApiBaseUrl = "http://127.0.0.1:8000",
  [string]$SttWsUrl = "ws://127.0.0.1:8002/asr",
  [switch]$Profile,
  [switch]$Release
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modeArg = if ($Release) {
  "--release"
} elseif ($Profile) {
  "--profile"
} else {
  "--profile"
}

adb -s $DeviceId reverse --remove-all | Out-Null
adb -s $DeviceId reverse tcp:8000 tcp:8000 | Out-Null
adb -s $DeviceId reverse tcp:8002 tcp:8002 | Out-Null
adb -s $DeviceId reverse --list

flutter run -d $DeviceId $modeArg `
  --dart-define=AEGIS_API_BASE_URL=$ApiBaseUrl `
  --dart-define=AEGIS_STT_WS_URL=$SttWsUrl
