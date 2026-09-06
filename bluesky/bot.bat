@echo off
cd /d "%~dp0"
ruby chorusdraft.rb %*
exit /b %errorlevel%
