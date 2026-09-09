@echo off
title GlobeTrotter Frontend Docker Launcher
echo =========================================================
echo Starting GlobeTrotter Frontend Container...
echo =========================================================
cd /d "%~dp0"

docker compose up -d
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start Docker container. Ensure Docker Desktop is running.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Container is running!
echo Opening http://localhost in your browser...
start http://localhost

