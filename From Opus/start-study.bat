@echo off
title KJV Strong's Study Server
echo ============================================
echo   KJV Strong's Bible — PC Study Mode
echo ============================================
echo.
echo Starting local server on http://localhost:8080/
echo Your browser will open automatically.
echo.
echo To stop the server, press Ctrl+C or close this window.
echo.
pwsh -ExecutionPolicy Bypass -NoProfile -File "%~dp0start-study.ps1"
echo.
echo Server stopped.
pause
