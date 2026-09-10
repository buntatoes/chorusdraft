@echo off
if not "%~1"=="" goto command
if exist "%~dp0launcher\ChorusDraft.exe" (
  start "" "%~dp0launcher\ChorusDraft.exe"
  exit /b 0
)
cd /d "%~dp0desktop"
call npm start
exit /b %errorlevel%
:command
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot.ps1" %*
exit /b %errorlevel%
