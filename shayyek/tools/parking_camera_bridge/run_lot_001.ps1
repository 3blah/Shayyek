param(
    [string]$CameraBaseUrl = "http://192.168.8.199",
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bridge = Join-Path $scriptDir "parking_camera_bridge.py"
$captureUrl = "$CameraBaseUrl/capture"

Write-Host "Checking camera snapshot: $captureUrl"
try {
    $response = Invoke-WebRequest -Uri $captureUrl -UseBasicParsing -TimeoutSec 10
    Write-Host "Camera OK: HTTP $($response.StatusCode), bytes=$($response.RawContentLength)"
} catch {
    Write-Host "Camera is not reachable from this computer: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure the ESP32 camera and this computer are on the same Wi-Fi, then rerun with the current IP." -ForegroundColor Yellow
    exit 1
}

$bridgeArgs = @(
    $bridge,
    "--camera-id", "camera_001",
    "--lot-id", "lot_001",
    "--camera-base-url", $CameraBaseUrl
)

if ($Once) {
    $bridgeArgs += "--once"
}

python @bridgeArgs
