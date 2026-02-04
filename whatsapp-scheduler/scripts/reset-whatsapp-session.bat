@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Reset WhatsApp Session
REM  Use this if you need to re-authenticate WhatsApp
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
set "PARENT_DIR=%PARENT_DIR:~0,-1%"
set "SESSION_DIR=%PARENT_DIR%\whatsapp-service\.wwebjs_auth"

echo.
echo   ===========================================================================
echo        WhatsApp Scheduler - Reset WhatsApp Session
echo   ===========================================================================
echo.
echo    This will:
 echo    1. Stop the WhatsApp service
echo    2. Delete the saved session data
echo    3. You will need to scan the QR code again
echo.
echo    Are you sure you want to continue? (Y/N)
set /p CONFIRM="    Choice: "

if /i not "!CONFIRM!"=="Y" (
    echo.
    echo    Operation cancelled.
    pause
    exit /b 0
)

echo.
echo    [..] Stopping WhatsApp service...

REM Kill WhatsApp service
for /f "tokens=5" %%a in ('netstat -ano ^| find ":3001 " ^| find "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1

timeout /t 2 /nobreak >nul

echo    [OK] WhatsApp service stopped
echo.
echo    [..] Deleting session data...

if exist "%SESSION_DIR%" (
    rmdir /s /q "%SESSION_DIR%" 2>nul
    if exist "%SESSION_DIR%" (
        echo    [!] Could not fully delete session - some files may be locked
        echo    [i] Try restarting your computer and running this again
    ) else (
        echo    [OK] Session data deleted
    )
) else (
    echo    [i] No session data found
)

echo.
echo    [OK] WhatsApp session reset complete!
echo.
echo    Next steps:
echo    1. Run start.bat to restart services
echo    2. Go to http://localhost:3000/connect
echo    3. Scan the new QR code with your phone
echo.

pause
