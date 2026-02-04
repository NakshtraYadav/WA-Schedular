@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Reinstall WhatsApp Dependencies
REM  Use this if WhatsApp service keeps failing
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "WA_DIR=%PARENT_DIR%\whatsapp-service"

echo.
echo   ===========================================================================
echo        WhatsApp Service - Full Reinstall
echo   ===========================================================================
echo.
echo    This will:
echo    1. Stop WhatsApp service
echo    2. Delete node_modules
echo    3. Delete session and cache
echo    4. Reinstall all dependencies
echo.
echo    This takes 5-10 minutes.
echo.
set /p CONFIRM="    Continue? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo    Cancelled.
    pause
    exit /b 0
)

echo.
echo    [1/5] Stopping services...

for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3001 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1
timeout /t 2 /nobreak >nul

echo    [OK] Services stopped
echo.
echo    [2/5] Deleting node_modules...

pushd "%WA_DIR%"

if exist "node_modules" (
    rmdir /s /q node_modules 2>nul
    echo    [OK] node_modules deleted
) else (
    echo    [i] node_modules not found
)

echo.
echo    [3/5] Deleting session and cache...

if exist ".wwebjs_auth" rmdir /s /q .wwebjs_auth 2>nul
if exist ".wwebjs_cache" rmdir /s /q .wwebjs_cache 2>nul
if exist "package-lock.json" del package-lock.json 2>nul
if exist "yarn.lock" del yarn.lock 2>nul
echo    [OK] Session and cache cleared

echo.
echo    [4/5] Installing dependencies (this takes 5-10 minutes)...
echo    [i] Downloading whatsapp-web.js and Chromium...
echo.

call npm install 2>&1

if !errorLevel! neq 0 (
    echo.
    echo    [!] npm install had issues, trying with --force...
    call npm install --force 2>&1
)

echo.
echo    [5/5] Verifying installation...

if exist "node_modules\whatsapp-web.js" (
    echo    [OK] whatsapp-web.js installed
) else (
    echo    [!!] whatsapp-web.js NOT installed - check errors above
)

if exist "node_modules\puppeteer" (
    echo    [OK] puppeteer installed
) else if exist "node_modules\puppeteer-core" (
    echo    [OK] puppeteer-core installed
) else (
    echo    [i] puppeteer will use system Chrome
)

popd

echo.
echo   ===========================================================================
echo                       REINSTALL COMPLETE!
echo   ===========================================================================
echo.
echo    Now run start.bat to start the services.
echo.
echo   ===========================================================================
echo.

pause
