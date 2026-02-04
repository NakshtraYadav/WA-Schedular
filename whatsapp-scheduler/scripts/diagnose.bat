@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Full System Diagnostics
REM  Generates detailed report for troubleshooting
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Go up one level to main directory
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,8%"
set "REPORT_FILE=%PARENT_DIR%\logs\system\diagnostic_report_%TIMESTAMP%.txt"

echo.
echo   ===========================================================================
echo              WhatsApp Scheduler - System Diagnostics
echo   ===========================================================================
echo.
echo    Generating diagnostic report...
echo    Output: %REPORT_FILE%
echo.

if not exist "%PARENT_DIR%\logs\system" mkdir "%PARENT_DIR%\logs\system"

(
    echo ============================================================================
    echo  WhatsApp Scheduler - Diagnostic Report
    echo  Generated: %date% %time%
    echo  Directory: %PARENT_DIR%
    echo ============================================================================
    echo.
    echo ----------------------------------------------------------------------------
    echo  SYSTEM INFORMATION
    echo ----------------------------------------------------------------------------
    echo.
    systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"Total Physical Memory"
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
    echo ----------------------------------------------------------------------------
    echo  PORT STATUS
    echo ----------------------------------------------------------------------------
    echo.
    echo Port 3000 (Frontend^):
    netstat -an | findstr ":3000 "
    echo.
    echo Port 8001 (Backend^):
    netstat -an | findstr ":8001 "
    echo.
    echo Port 3001 (WhatsApp^):
    netstat -an | findstr ":3001 "
    echo.
    echo Port 27017 (MongoDB^):
    netstat -an | findstr ":27017 "
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
