@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Fix WhatsApp (Clear Session)
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "WA_DIR=%PARENT_DIR%\whatsapp-service"
set "SESSION_DIR=%WA_DIR%\.wwebjs_auth"
set "CACHE_DIR=%WA_DIR%\.wwebjs_cache"

echo.
echo   ===========================================================================
echo        WhatsApp Fix - Clear Session and Cache
echo   ===========================================================================
echo.
echo    This fixes:
echo    - "Navigating frame was detached"
echo    - "Target closed"
echo    - "All connection attempts failed"
echo    - WhatsApp not initializing
echo.
echo    You will need to scan the QR code again.
echo.
set /p CONFIRM="    Continue? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo    Cancelled.
    pause
    exit /b 0
)

echo.
echo    [1/3] Stopping WhatsApp service...

for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3001 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1

REM Kill any lingering node processes
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='node.exe' and commandline like '%%whatsapp%%'" get processid 2^>nul') do (
    if "%%a" neq "" taskkill /F /PID %%a >nul 2>&1
)

timeout /t 3 /nobreak >nul
echo    [OK] Service stopped

echo.
echo    [2/3] Deleting session data...

if exist "%SESSION_DIR%" (
    rmdir /s /q "%SESSION_DIR%" 2>nul
    timeout /t 1 /nobreak >nul
    if exist "%SESSION_DIR%" (
        echo    [!] Could not fully delete - trying again...
        rmdir /s /q "%SESSION_DIR%" 2>nul
    )
    if not exist "%SESSION_DIR%" (
        echo    [OK] Session deleted
    ) else (
        echo    [!] Some files locked - restart PC and try again
    )
) else (
    echo    [i] No session found
)

echo.
echo    [3/3] Deleting cache data...

if exist "%CACHE_DIR%" (
    rmdir /s /q "%CACHE_DIR%" 2>nul
    echo    [OK] Cache deleted
) else (
    echo    [i] No cache found
)

echo.
echo   ===========================================================================
echo                           FIX COMPLETE!
echo   ===========================================================================
echo.
echo    Next steps:
echo    1. Run start.bat to restart services
echo    2. Wait 30-90 seconds for QR code
echo    3. Scan QR code with your phone
echo.
echo    If it still fails:
echo    - Run scripts\reinstall-whatsapp.bat
echo    - Make sure Chrome or Edge is installed
echo.
echo   ===========================================================================
echo.

pause
