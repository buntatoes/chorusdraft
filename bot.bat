@echo off
if not "%~1"=="" goto command
if exist "%~dp0launcher\ChorusDraft.exe" (
  start "" "%~dp0launcher\ChorusDraft.exe"
  exit /b 0
)
pyw -3 "%~dp0launcher\app.py"
exit /b %errorlevel%
:command
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot.ps1" %*
exit /b %errorlevel%
