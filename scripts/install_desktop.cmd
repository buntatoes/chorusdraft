@echo off
setlocal
cd /d "%~dp0"
where pwsh >nul 2>&1
if %ERRORLEVEL%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
) else (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
)
if errorlevel 1 pause
