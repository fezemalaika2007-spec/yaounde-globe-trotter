@echo off
REM ============================================================
REM  GlobeTrotter Web Launcher & Service Runner
REM  Builds and serves the Flutter Web App.
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
set "API_BASE_URL=http://localhost:5000"

cd services
echo === Starting local API services ===
call docker compose up --build -d user-service itinerary-service recommendation-service api-gateway

if errorlevel 1 (
    echo.
    echo Backend startup FAILED. Check Docker and services\.env configuration.
    pause
    exit /b 1
)

cd ..\frontend

echo.
echo === API Gateway: %API_BASE_URL% ===
echo === Building web bundle ===
call flutter build web --base-href / --no-tree-shake-icons --dart-define=API_BASE_URL=%API_BASE_URL%

if errorlevel 1 (
    echo.
    echo Build FAILED. Check the errors above.
    pause
    exit /b 1
)

echo.
echo === Starting static web server on http://localhost:8080 ===
cd build\web
echo Opening browser...
start "" http://localhost:8080/
python -m http.server 8080

endlocal
