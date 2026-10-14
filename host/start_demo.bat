@echo off
cd /d "%~dp0"
python app.py --demo
if errorlevel 1 pause
