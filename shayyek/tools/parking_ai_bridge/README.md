# Shayyek Parking AI Bridge

This local service runs the YOLO parking detector from `assets/models/parking_detector_fast.pt`.
It exposes:

- `GET /health`
- `POST /analyze-parking` with multipart field `image` and optional `lot_id`
- `POST /analyze-url` with JSON `{ "url": "http://camera/capture", "lot_id": "lot_001" }`

Run it on the computer connected to the same Wi-Fi as the phone:

```powershell
cd C:\development\flutter-apps\shayyek
python -m pip install -r tools\parking_ai_bridge\requirements.txt
tools\parking_ai_bridge\start_parking_ai_bridge.bat
```

Then set the app value `app_settings/parking_ai_bridge_url` to the computer URL, for example:

```text
http://192.168.8.100:8000
```
