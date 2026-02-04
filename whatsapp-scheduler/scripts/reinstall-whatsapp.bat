@echo off
REM ============================================================================
REM  WhatsApp Service - Full Reinstall (v3.0)
REM  Uses whatsapp-web.js@1.34.6 (latest stable)
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "WA_DIR=%PARENT_DIR%\whatsapp-service"

echo.
echo   ===========================================================================
echo        WhatsApp Service - Full Reinstall (v3.0)
echo   ===========================================================================
echo.
echo    This will:
echo    1. Stop WhatsApp service
echo    2. Delete node_modules, session, cache, and lock files
echo    3. Reinstall whatsapp-web.js@1.34.6 (latest stable)
echo.
echo    This takes 3-5 minutes depending on your internet speed.
echo.
set /p CONFIRM="    Continue? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo    Cancelled.
    pause
    exit /b 0
)

echo.
echo    [1/6] Stopping services...

for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":3001 " ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1
timeout /t 2 /nobreak >nul
echo    [OK] Services stopped

echo.
echo    [2/6] Deleting node_modules...

pushd "%WA_DIR%"

if exist "node_modules" (
    rmdir /s /q node_modules 2>nul
    echo    [OK] node_modules deleted
) else (
    echo    [i] node_modules not found
)

echo.
echo    [3/6] Deleting session and cache...

if exist ".wwebjs_auth" rmdir /s /q .wwebjs_auth 2>nul
if exist ".wwebjs_cache" rmdir /s /q .wwebjs_cache 2>nul
if exist "package-lock.json" del package-lock.json 2>nul
if exist "yarn.lock" del yarn.lock 2>nul
echo    [OK] Session, cache, and lock files cleared

echo.
echo    [4/6] Verifying package.json...

REM Check if package.json has the correct version
findstr /C:"1.34" package.json >nul 2>&1
if !errorLevel! neq 0 (
    echo    [!] Updating package.json to use whatsapp-web.js@1.34.6...
    
    REM Create updated package.json
    (
        echo {
        echo   "name": "whatsapp-service",
        echo   "version": "3.0.0",
        echo   "description": "WhatsApp Web automation service",
        echo   "main": "index.js",
        echo   "scripts": {
        echo     "start": "node index.js",
        echo     "clean": "node -e \"const fs=require('fs');['.wwebjs_auth','.wwebjs_cache'].forEach(p=^>{if(fs.existsSync(p^)){fs.rmSync(p,{recursive:true});console.log('Cleared:',p^)}}^)\""
        echo   },
        echo   "dependencies": {
        echo     "whatsapp-web.js": "^1.34.6",
        echo     "qrcode": "^1.5.3",
        echo     "express": "^4.18.2",
        echo     "cors": "^2.8.5"
        echo   },
        echo   "engines": {
        echo     "node": "^>=18.0.0"
        echo   }
        echo }
    ) > package.json.new
    move /y package.json.new package.json >nul
    echo    [OK] package.json updated
) else (
    echo    [OK] package.json already has correct version
)

echo.
echo    [5/6] Installing dependencies...
echo    [i] This downloads whatsapp-web.js + puppeteer + chromium (~200MB)...
echo.

REM Clean npm cache first to avoid issues
call npm cache clean --force >nul 2>&1

REM Install with explicit registry
call npm install --registry https://registry.npmjs.org/ 2>&1

if !errorLevel! neq 0 (
    echo.
    echo    [!] First attempt failed, retrying with --legacy-peer-deps...
    call npm install --legacy-peer-deps --registry https://registry.npmjs.org/ 2>&1
)

echo.
echo    [6/6] Verifying installation...

set "INSTALL_OK=1"

if exist "node_modules\whatsapp-web.js" (
    echo    [OK] whatsapp-web.js installed
    
    REM Check version
    for /f "tokens=2 delims=:" %%a in ('findstr /C:"version" node_modules\whatsapp-web.js\package.json 2^>nul ^| findstr /V "engines"') do (
        echo    [i] Version: %%a
    )
) else (
    echo    [!!] whatsapp-web.js NOT installed
    set "INSTALL_OK=0"
)

if exist "node_modules\puppeteer" (
    echo    [OK] puppeteer installed
) else (
    echo    [!] puppeteer not found - checking if bundled with whatsapp-web.js
)

REM Check for chromium in various locations
if exist "node_modules\puppeteer\.local-chromium" (
    echo    [OK] Chromium downloaded (puppeteer/.local-chromium)
) else if exist "node_modules\puppeteer\chrome" (
    echo    [OK] Chrome found (puppeteer/chrome)
) else if exist "node_modules\.cache\puppeteer" (
    echo    [OK] Chromium cached (.cache/puppeteer)
) else (
    echo    [i] Will use system Chrome/Edge
)

popd

echo.
if "%INSTALL_OK%"=="1" (
    echo   ===========================================================================
    echo                       REINSTALL COMPLETE!
    echo   ===========================================================================
    echo.
    echo    WhatsApp service is now using:
    echo      - whatsapp-web.js@1.34.6 (latest stable)
    echo      - Puppeteer (bundled by whatsapp-web.js)
    echo.
    echo    Now run start.bat to start the services.
    echo.
) else (
    echo   ===========================================================================
    echo                       REINSTALL FAILED
    echo   ===========================================================================
    echo.
    echo    Please check:
    echo    1. Your internet connection
    echo    2. Run as Administrator
    echo    3. Temporarily disable antivirus
    echo    4. Try: npm cache clean --force
    echo.
)
echo   ===========================================================================
echo.

pause
