@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Clear WhatsApp Session (Fixes "Frame Detached" error)
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "SESSION_DIR=%PARENT_DIR%\whatsapp-service\.wwebjs_auth"
set "CACHE_DIR=%PARENT_DIR%\whatsapp-service\.wwebjs_cache"

echo.
echo   ===========================================================================
echo        WhatsApp Session Clear - Fixes "Frame Detached" Error
echo   ===========================================================================
echo.
echo    This will:
echo    1. Stop any running WhatsApp service
echo    2. Delete session data (.wwebjs_auth)
echo    3. Delete cache data (.wwebjs_cache)
echo    4. You will need to scan the QR code again
echo.
echo    This is the recommended fix for:
echo    - "Navigating frame was detached"
echo    - "Target closed"
 echo    - "Protocol error"
echo    - WhatsApp not initializing
echo.
set /p CONFIRM="    Continue? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo.
    echo    Cancelled.
    pause
    exit /b 0
)

echo.
echo    [..] Stopping WhatsApp service...

REM Kill WhatsApp service by port
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3001 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)

REM Kill by window title
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1

REM Kill any node processes that might be holding files
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='node.exe' and commandline like '%%whatsapp%%'" get processid 2^>nul') do (
    if "%%a" neq "" taskkill /F /PID %%a >nul 2>&1
)

timeout /t 3 /nobreak >nul
echo    [OK] Services stopped

echo.
echo    [..] Deleting session data...

if exist "%SESSION_DIR%" (
    rmdir /s /q "%SESSION_DIR%" 2>nul
    if exist "%SESSION_DIR%" (
        REM Try harder - sometimes files are locked
        timeout /t 2 /nobreak >nul
        rmdir /s /q "%SESSION_DIR%" 2>nul
    )
    if exist "%SESSION_DIR%" (
        echo    [!] Could not delete session - files may be locked
        echo    [i] Try restarting your computer
    ) else (
        echo    [OK] Session data deleted
    )
) else (
    echo    [i] No session data found
)

echo.
echo    [..] Deleting cache data...

if exist "%CACHE_DIR%" (
    rmdir /s /q "%CACHE_DIR%" 2>nul
    if exist "%CACHE_DIR%" (
        echo    [!] Could not delete cache completely
    ) else (
        echo    [OK] Cache data deleted
    )
) else (
    echo    [i] No cache data found
)

echo.
echo   ===========================================================================
echo                           SESSION CLEARED!
echo   ===========================================================================
echo.
echo    Next steps:
echo    1. Run start.bat to restart all services
echo    2. Go to http://localhost:3000/connect
echo    3. Wait for the QR code (30-90 seconds)
echo    4. Scan with your phone
echo.
echo   ===========================================================================
echo.

pause
