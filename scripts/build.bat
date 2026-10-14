@echo off
cd /d "%~dp0\.."
python scripts/close_timing.py
exit /b %errorlevel%
