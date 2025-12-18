@echo off
REM Development mode startup script
echo Starting EagilinsED in Development Mode (Auto-Reload)...
call venv\Scripts\activate.bat
python run_dev.py
pause

