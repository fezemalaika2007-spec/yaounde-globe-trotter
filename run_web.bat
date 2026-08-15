@echo off
REM ============================================================
REM  GlobeTrotter Web Launcher
REM  Builds the Flutter web app and serves it statically.
REM  Requires: Python for HTTP server.
REM ============================================================
setlocal
cd /d "%~dp0frontend"

echo.
echo === Building web bundle ===
call flutter build web --base-href /
if errorlevel 1 (
    echo.
    echo Build FAILED. Check the errors above.
    pause
    exit /b 1
)

echo.
echo === Starting static server on http://localhost:8080 ===
cd build\web
echo Opening browser...
start "" http://localhost:8080/
python -m http.server 8080

endlocal
