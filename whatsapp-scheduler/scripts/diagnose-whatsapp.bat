@echo off
REM ============================================================================
REM  WhatsApp Diagnostic Tool - Find the exact issue
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "WA_DIR=%PARENT_DIR%\whatsapp-service"

echo.
echo   ===========================================================================
echo        WhatsApp Diagnostic Tool
echo   ===========================================================================
echo.
echo   This will help identify why WhatsApp is failing.
echo.
echo   ===========================================================================
echo.

echo   [1/6] Checking Node.js version...
node -v
if %errorLevel% neq 0 (
    echo   [!!] Node.js not found! Install from https://nodejs.org/
    goto :end
)
echo.

echo   [2/6] Checking for Chrome/Edge...
set "CHROME_FOUND=0"

if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo   [OK] Chrome found at: C:\Program Files\Google\Chrome\Application\chrome.exe
    set "CHROME_FOUND=1"
)
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    echo   [OK] Chrome found at: C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
    set "CHROME_FOUND=1"
)
if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" (
    echo   [OK] Chrome found at: %LOCALAPPDATA%\Google\Chrome\Application\chrome.exe
    set "CHROME_FOUND=1"
)
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
    echo   [OK] Edge found at: C:\Program Files\Microsoft\Edge\Application\msedge.exe
    set "CHROME_FOUND=1"
)
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    echo   [OK] Edge found at: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
    set "CHROME_FOUND=1"
)

if "%CHROME_FOUND%"=="0" (
    echo   [!!] NO BROWSER FOUND!
    echo   [!!] Install Google Chrome from https://www.google.com/chrome/
    echo.
)
echo.

echo   [3/6] Checking WhatsApp service files...
pushd "%WA_DIR%"

if exist "package.json" (
    echo   [OK] package.json exists
) else (
    echo   [!!] package.json MISSING
)

if exist "index.js" (
    echo   [OK] index.js exists
) else (
    echo   [!!] index.js MISSING
)

if exist "node_modules\whatsapp-web.js" (
    echo   [OK] whatsapp-web.js installed
) else (
    echo   [!!] whatsapp-web.js NOT installed - run setup.bat
)

if exist "node_modules\puppeteer" (
    echo   [OK] puppeteer installed
    if exist "node_modules\puppeteer\.local-chromium" (
        echo   [OK] Puppeteer Chromium downloaded
    ) else if exist "node_modules\puppeteer\chrome" (
        echo   [OK] Puppeteer Chrome found
    ) else (
        echo   [i] Puppeteer will use system Chrome
    )
) else (
    echo   [!!] puppeteer NOT installed
)
echo.

echo   [4/6] Checking for session/cache conflicts...
if exist ".wwebjs_auth" (
    echo   [!] Session folder exists - may be corrupted
    echo   [i] Consider deleting: %WA_DIR%\.wwebjs_auth
) else (
    echo   [OK] No old session data
)

if exist ".wwebjs_cache" (
    echo   [!] Cache folder exists
) else (
    echo   [OK] No cache data
)
echo.

echo   [5/6] Checking port 3001...
netstat -an | findstr ":3001 " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo   [!] Port 3001 is in use
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3001 " ^| findstr "LISTENING"') do (
        echo   [i] Used by PID: %%a
    )
) else (
    echo   [OK] Port 3001 is free
)
echo.

echo   [6/6] Running WhatsApp test with verbose logging...
echo.
echo   ===========================================================================
echo   Starting WhatsApp service with DEBUG mode...
echo   Watch for errors below. Press Ctrl+C to stop.
echo   ===========================================================================
echo.

set DEBUG=puppeteer:*,whatsapp-web.js:*
node index.js

popd

:end
echo.
pause
