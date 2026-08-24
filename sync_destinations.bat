@echo off
echo.
echo =======================================================
echo    Yaounde Globe Trotter - Destination Synchronizer
echo =======================================================
echo.
echo Parsing destinations.txt and syncing to app...
echo.

python services\recommendation-service\parse_and_sync_destinations.py

if errorlevel 1 (
    echo.
    echo Sync FAILED. Please check the error above.
    pause
    exit /b 1
)

echo.
echo =======================================================
echo  SUCCESS! All destinations in destinations.txt have
echo  been synchronized and added to your app.
echo.
echo  Go to your browser at http://localhost:8080/
echo  and press Ctrl + Shift + R to see your new places!
echo =======================================================
echo.
pause

