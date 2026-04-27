# Parking Camera Bridge

This bridge reads frames from the ESP32 camera stream, runs the PyTorch models
inside `assets/models`, then writes occupancy summaries into the existing
Firebase Realtime Database nodes:

- `CameraHealth`
- `live_map`
- `stalls`

## Run

```powershell
python -m pip install -r tools/parking_camera_bridge/requirements.txt
python tools/parking_camera_bridge/parking_camera_bridge.py `
  --camera-id camera_001 `
  --camera-base-url http://192.168.1.77 `
  --database-url https://smartpasrk-default-rtdb.firebaseio.com
```

If your Realtime Database rules allow public writes, `--service-account` is optional.
If the database is locked down, pass the Firebase service account as before.

## One-command start

```powershell
powershell -ExecutionPolicy Bypass -File tools/parking_camera_bridge/start_bridge.ps1 `
  -CameraId camera_001 `
  -LotId lot_001 `
  -CameraBaseUrl http://192.168.1.77
```

## Notes

- The ESP32 sketch should expose `/stream` and `/capture`.
- The bridge uses the existing `stalls/<id>/polygon` coordinates to crop each
  stall for classification.
- If `ORS_API_KEY` is configured in Flutter, the app will show a routed road
  path. Otherwise it falls back to a direct line.
