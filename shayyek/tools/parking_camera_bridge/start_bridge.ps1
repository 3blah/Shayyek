param(
    [Parameter(Mandatory = $true)]
    [string]$CameraId,

    [Parameter(Mandatory = $false)]
    [string]$LotId = "",

    [Parameter(Mandatory = $true)]
    [string]$CameraBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccount = "",

    [Parameter(Mandatory = $false)]
    [string]$DatabaseUrl = "https://smartpasrk-default-rtdb.firebaseio.com",

    [Parameter(Mandatory = $false)]
    [double]$LoopSeconds = 3.0
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Push-Location $repoRoot
try {
    python -m pip install -r tools/parking_camera_bridge/requirements.txt

    $args = @(
        "tools/parking_camera_bridge/parking_camera_bridge.py",
        "--camera-id", $CameraId,
        "--camera-base-url", $CameraBaseUrl,
        "--database-url", $DatabaseUrl,
        "--loop-seconds", $LoopSeconds
    )

    if ($ServiceAccount.Trim()) {
        $args += @("--service-account", $ServiceAccount)
    }

    if ($LotId.Trim()) {
        $args += @("--lot-id", $LotId)
    }

    python @args
}
finally {
    Pop-Location
}
