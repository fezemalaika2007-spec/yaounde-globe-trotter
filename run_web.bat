@echo off
REM ============================================================
REM  GlobeTrotter Web Launcher & Service Runner
REM  Starts Backend Recommendation Service & Serves Web App.
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo === Starting GlobeTrotter Backend Service (Port 5003) ===
start "GlobeTrotter Backend" /B python services\recommendation-service\app\main.py

cd frontend

echo.
echo === Building web bundle ===
call flutter build web --base-href / --no-tree-shake-icons

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
