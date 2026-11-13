@echo off
title GlobeTrotter Frontend Docker Launcher
echo =========================================================
echo Starting GlobeTrotter Frontend Container...
echo =========================================================
cd /d "%~dp0"
set "PATH=%SystemRoot%\System32;%SystemRoot%\System32\WindowsPowerShell\v1.0;%PATH%"
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%ProgramFiles%\Git\bin;%PATH%"

echo Starting local API services...
cd ..\services
call docker compose up --build -d user-service itinerary-service recommendation-service api-gateway
if errorlevel 1 goto backend_failed

cd ..\frontend
echo Building the Flutter Web app with the local API URL...
call flutter build web --release --base-href / --no-tree-shake-icons --dart-define=API_BASE_URL=http://localhost:5000
if errorlevel 1 goto flutter_build_failed

echo Packaging and starting the frontend container...
call docker compose up --build -d --force-recreate globetrotter-frontend
if errorlevel 1 goto frontend_failed

echo.
echo [SUCCESS] Local app is running at http://localhost:8080
start "" http://localhost:8080/
exit /b 0

:backend_failed
echo [ERROR] Failed to start local API services. Check Docker and services\.env.
pause
exit /b 1

:frontend_failed
echo [ERROR] Failed to build or start the frontend container.
pause
exit /b 1

:flutter_build_failed
echo [ERROR] Flutter Web build failed. Check the Flutter SDK and build output.
pause
exit /b 1

