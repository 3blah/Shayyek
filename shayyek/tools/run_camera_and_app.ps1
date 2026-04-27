param(
    [Parameter(Mandatory = $true)]
    [string]$CameraBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$CameraId = "camera_001",

    [Parameter(Mandatory = $false)]
    [string]$LotId = "lot_001",

    [Parameter(Mandatory = $false)]
    [string]$DeviceId = "",

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccount = "",

    [Parameter(Mandatory = $false)]
    [string]$DatabaseUrl = "https://smartpasrk-default-rtdb.firebaseio.com",

    [Parameter(Mandatory = $false)]
    [string]$OrsApiKey = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$bridgeScript = Join-Path $repoRoot "tools\parking_camera_bridge\start_bridge.ps1"

Write-Host "== Checking camera endpoint ==" -ForegroundColor Cyan
try {
    $captureUrl = "{0}/capture" -f $CameraBaseUrl.TrimEnd("/")
    $response = Invoke-WebRequest -Uri $captureUrl -TimeoutSec 10
    Write-Host "Camera reachable: $captureUrl (HTTP $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Warning "Camera did not respond on $captureUrl . The bridge may fail until the ESP32 is reachable."
}

Write-Host "== Starting AI bridge in a new PowerShell window ==" -ForegroundColor Cyan
$bridgeArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$bridgeScript`"",
    "-CameraId", "`"$CameraId`"",
    "-LotId", "`"$LotId`"",
    "-CameraBaseUrl", "`"$CameraBaseUrl`"",
    "-DatabaseUrl", "`"$DatabaseUrl`""
)

if ($ServiceAccount.Trim()) {
    $bridgeArgs += @("-ServiceAccount", "`"$ServiceAccount`"")
}

$bridgeArgumentLine = $bridgeArgs -join " "
Start-Process powershell -ArgumentList $bridgeArgumentLine -WorkingDirectory $repoRoot

Push-Location $repoRoot
try {
    Write-Host "== Preparing Flutter app ==" -ForegroundColor Cyan
    flutter clean
    flutter pub get

    $flutterArgs = @("run")
    if ($DeviceId.Trim()) {
        $flutterArgs += @("-d", $DeviceId)
    }
    if ($OrsApiKey.Trim()) {
        $flutterArgs += @("--dart-define=ORS_API_KEY=$OrsApiKey")
    }

    Write-Host "== Launching Flutter app ==" -ForegroundColor Cyan
    flutter @flutterArgs
} finally {
    Pop-Location
}
