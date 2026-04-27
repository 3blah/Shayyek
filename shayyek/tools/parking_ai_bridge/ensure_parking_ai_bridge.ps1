param(
  [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Script = Join-Path $Root 'tools\parking_ai_bridge\parking_ai_bridge.py'

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1

if ($listener) {
  Write-Output "Parking AI bridge already listening on port $Port."
  exit 0
}

$args = @(
  $Script,
  '--host', '0.0.0.0',
  '--port', "$Port"
)

Start-Process -FilePath 'python' -ArgumentList $args -WorkingDirectory $Root -WindowStyle Hidden

for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 1
  $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($listener) {
    break
  }
}

if (-not $listener) {
  throw "Parking AI bridge did not start on port $Port."
}

Write-Output "Parking AI bridge started on port $Port."
