@echo off
cd /d "%~dp0\..\.."
python tools\parking_ai_bridge\parking_ai_bridge.py --host 0.0.0.0 --port 8000
