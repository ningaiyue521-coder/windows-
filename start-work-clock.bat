@echo off
set "SCRIPT=%~dp0workday-floating-clock.ps1"
start "" powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT%"
exit /b 0
