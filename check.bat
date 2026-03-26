@echo off
title SECURITY CHECK
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0security.ps1"
echo.
pause