param(
  [string]$DeviceId = 'R5CW41LN77D',
  [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')

& (Join-Path $PSScriptRoot 'ensure_parking_ai_bridge.ps1') -Port $Port

Set-Location $Root
flutter build apk --release
flutter install -d $DeviceId

$adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
if (Test-Path $adb) {
  & $adb -s $DeviceId shell monkey -p com.example.shayyek -c android.intent.category.LAUNCHER 1
}
