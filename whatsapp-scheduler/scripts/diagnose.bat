@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Full System Diagnostics
REM  Generates detailed report for troubleshooting
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
set "PARENT_DIR=%PARENT_DIR:~0,-1%"
set "REPORT_FILE=%PARENT_DIR%\logs\system\diagnostic_report_%date:~-4,4%%date:~-7,2%%date:~-10,2%.txt"

echo.
echo   ===========================================================================
echo              WhatsApp Scheduler - System Diagnostics
echo   ===========================================================================
echo.
echo    Generating diagnostic report...
echo    Output: %REPORT_FILE%
echo.

(
    echo ============================================================================
    echo  WhatsApp Scheduler - Diagnostic Report
    echo  Generated: %date% %time%
    echo ============================================================================
    echo.
    echo ----------------------------------------------------------------------------
    echo  SYSTEM INFORMATION
    echo ----------------------------------------------------------------------------
    echo.
    systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory" /C:"Available Physical Memory"
    echo.
    echo ----------------------------------------------------------------------------
    echo  DEPENDENCY VERSIONS
    echo ----------------------------------------------------------------------------
    echo.
    echo Node.js:
    node -v 2>&1
    echo.
    echo npm:
    npm -v 2>&1
    echo.
    echo Python:
    python --version 2>&1
    echo.
    echo pip:
    python -m pip --version 2>&1
    echo.
    echo ----------------------------------------------------------------------------
    echo  PORT STATUS
    echo ----------------------------------------------------------------------------
    echo.
    echo Port 3000 (Frontend^):
    netstat -an | find ":3000 "
    echo.
    echo Port 8001 (Backend^):
    netstat -an | find ":8001 "
    echo.
    echo Port 3001 (WhatsApp^):
    netstat -an | find ":3001 "
    echo.
    echo Port 27017 (MongoDB^):
    netstat -an | find ":27017 "
    echo.
    echo ----------------------------------------------------------------------------
    echo  ENVIRONMENT FILES
    echo ----------------------------------------------------------------------------
    echo.
    echo Backend .env:
    if exist "%PARENT_DIR%\backend\.env" (
        type "%PARENT_DIR%\backend\.env"
    ) else (
        echo [NOT FOUND]
    )
    echo.
    echo Frontend .env:
    if exist "%PARENT_DIR%\frontend\.env" (
        type "%PARENT_DIR%\frontend\.env"
    ) else (
        echo [NOT FOUND]
    )
    echo.
    echo ----------------------------------------------------------------------------
    echo  DIRECTORY STRUCTURE
    echo ----------------------------------------------------------------------------
    echo.
    dir /b "%PARENT_DIR%"
    echo.
    echo Backend:
    if exist "%PARENT_DIR%\backend" dir /b "%PARENT_DIR%\backend"
    echo.
    echo Frontend:
    if exist "%PARENT_DIR%\frontend" dir /b "%PARENT_DIR%\frontend" | find /v "node_modules"
    echo.
    echo WhatsApp Service:
    if exist "%PARENT_DIR%\whatsapp-service" dir /b "%PARENT_DIR%\whatsapp-service" | find /v "node_modules"
    echo.
    echo ----------------------------------------------------------------------------
    echo  SERVICE HEALTH CHECKS
    echo ----------------------------------------------------------------------------
    echo.
    echo Backend API:
    curl -s http://localhost:8001/api/ 2>&1
    echo.
    echo.
    echo WhatsApp Service:
    curl -s http://localhost:3001/status 2>&1
    echo.
    echo.
    echo Frontend:
    curl -s -o nul -w "HTTP Status: %%{http_code}" http://localhost:3000 2>&1
    echo.
    echo.
    echo ----------------------------------------------------------------------------
    echo  RECENT ERROR LOGS
    echo ----------------------------------------------------------------------------
    echo.
    echo Backend (last 20 lines^):
    if exist "%PARENT_DIR%\logs\backend" (
        for /f "delims=" %%f in ('dir /b /od "%PARENT_DIR%\logs\backend\*.log" 2^>nul') do set "LATEST_BE=%%f"
        if defined LATEST_BE (
            more +0 "%PARENT_DIR%\logs\backend\!LATEST_BE!" | findstr /i "error exception fail" 2>nul | more +0
        )
    )
    echo.
    echo WhatsApp (last 20 lines^):
    if exist "%PARENT_DIR%\logs\whatsapp" (
        for /f "delims=" %%f in ('dir /b /od "%PARENT_DIR%\logs\whatsapp\*.log" 2^>nul') do set "LATEST_WA=%%f"
        if defined LATEST_WA (
            more +0 "%PARENT_DIR%\logs\whatsapp\!LATEST_WA!" | findstr /i "error exception fail" 2>nul | more +0
        )
    )
    echo.
    echo ----------------------------------------------------------------------------
    echo  END OF REPORT
    echo ----------------------------------------------------------------------------
) > "%REPORT_FILE%" 2>&1

echo    [OK] Diagnostic report generated!
echo.
echo    Opening report...
start notepad "%REPORT_FILE%"
echo.
pause
