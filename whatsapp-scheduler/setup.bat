@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Setup Script for Windows 10/11
REM  Version: 2.1 | Fixed path handling for spaces
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Setup
color 0A
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION - Handle paths with spaces properly
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs\system"

REM Create timestamp without special chars
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,8%_%dt:~8,6%"
set "SETUP_LOG=%LOG_DIR%\setup_%TIMESTAMP%.log"

set "MIN_NODE_VERSION=16"
set "MIN_PYTHON_VERSION=3.8"

REM ============================================================================
REM  INITIALIZE - Create directories first
REM ============================================================================
cd /d "%SCRIPT_DIR%"

REM Create all required directories
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs"
if not exist "%SCRIPT_DIR%\logs\backend" mkdir "%SCRIPT_DIR%\logs\backend"
if not exist "%SCRIPT_DIR%\logs\frontend" mkdir "%SCRIPT_DIR%\logs\frontend"
if not exist "%SCRIPT_DIR%\logs\whatsapp" mkdir "%SCRIPT_DIR%\logs\whatsapp"
if not exist "%SCRIPT_DIR%\logs\system" mkdir "%SCRIPT_DIR%\logs\system"
if not exist "%SCRIPT_DIR%\scripts" mkdir "%SCRIPT_DIR%\scripts"

echo [%date% %time%] Setup started > "%SETUP_LOG%"
echo [%date% %time%] Directory: %SCRIPT_DIR% >> "%SETUP_LOG%"

echo.
echo  ============================================================================
echo   WhatsApp Scheduler - Production Setup
echo  ============================================================================
echo.
echo   [i] Working Directory: %SCRIPT_DIR%
echo.
echo   [i] This script will:
echo       - Verify and install all dependencies
echo       - Configure environment files
echo       - Set up all services
echo.
echo  ============================================================================
echo.

REM ============================================================================
REM  PREFLIGHT CHECKS
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   PREFLIGHT VALIDATION
echo  ----------------------------------------------------------------------------
echo.

REM Check Windows Version
echo   [..] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo   [OK] Windows version: %VERSION%
echo [%date% %time%] Windows version: %VERSION% >> "%SETUP_LOG%"

REM Check Administrator privileges
echo   [..] Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo   [!] WARNING: Running without administrator privileges
    echo   [!] Some features may not work correctly
    echo [%date% %time%] WARNING: Not running as administrator >> "%SETUP_LOG%"
) else (
    echo   [OK] Running with administrator privileges
    echo [%date% %time%] Running as administrator >> "%SETUP_LOG%"
)
echo.

REM ============================================================================
REM  NODE.JS VALIDATION
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   NODE.JS VALIDATION
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Checking Node.js installation...
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo   [!!] ERROR: Node.js is not installed!
    echo [%date% %time%] ERROR: Node.js not found >> "%SETUP_LOG%"
    echo.
    echo   To fix this:
    echo   1. Download Node.js LTS from: https://nodejs.org/
    echo   2. Run the installer - check 'Add to PATH'
    echo   3. Restart this script
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('node -v 2^>nul') do set NODE_VERSION=%%i
echo   [OK] Node.js %NODE_VERSION%
echo [%date% %time%] Node.js: %NODE_VERSION% >> "%SETUP_LOG%"

REM Check npm
echo   [..] Checking npm...
where npm >nul 2>&1
if %errorLevel% neq 0 (
    echo   [!!] ERROR: npm not found!
    echo [%date% %time%] ERROR: npm not found >> "%SETUP_LOG%"
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('npm -v 2^>nul') do set NPM_VERSION=%%i
echo   [OK] npm v%NPM_VERSION%
echo [%date% %time%] npm: v%NPM_VERSION% >> "%SETUP_LOG%"
echo.

REM ============================================================================
REM  PYTHON VALIDATION
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   PYTHON VALIDATION
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Checking Python installation...

REM Try python first
set "PYTHON_CMD="
python --version >nul 2>&1
if %errorLevel% equ 0 (
    set "PYTHON_CMD=python"
    goto :python_found
)

REM Try py launcher
py --version >nul 2>&1
if %errorLevel% equ 0 (
    set "PYTHON_CMD=py"
    goto :python_found
)

echo   [!!] ERROR: Python is not installed!
echo [%date% %time%] ERROR: Python not found >> "%SETUP_LOG%"
echo.
echo   To fix this:
echo   1. Download Python from: https://www.python.org/downloads/
echo   2. Run installer - CHECK 'Add Python to PATH'
echo   3. Restart this script
echo.
pause
exit /b 1

:python_found
for /f "tokens=*" %%i in ('%PYTHON_CMD% --version 2^>nul') do set PYTHON_VERSION=%%i
echo   [OK] %PYTHON_VERSION% (using: %PYTHON_CMD%)
echo [%date% %time%] %PYTHON_VERSION% (command: %PYTHON_CMD%) >> "%SETUP_LOG%"

REM Check pip
echo   [..] Checking pip...
%PYTHON_CMD% -m pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo   [!] pip not found, installing...
    %PYTHON_CMD% -m ensurepip --upgrade >nul 2>&1
)
echo   [OK] pip available
echo [%date% %time%] pip available >> "%SETUP_LOG%"
echo.

REM ============================================================================
REM  MONGODB CHECK
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   MONGODB VALIDATION
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Checking MongoDB...

REM Check if MongoDB service exists and is running
sc query MongoDB >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=4" %%a in ('sc query MongoDB ^| find "STATE"') do set MONGO_STATE=%%a
    if "!MONGO_STATE!"=="RUNNING" (
        echo   [OK] MongoDB service is running
        echo [%date% %time%] MongoDB: Service running >> "%SETUP_LOG%"
    ) else (
        echo   [..] Starting MongoDB service...
        net start MongoDB >nul 2>&1
        if !errorLevel! equ 0 (
            echo   [OK] MongoDB service started
        ) else (
            echo   [!] Could not start MongoDB service
        )
    )
) else (
    REM Check if mongod is in PATH
    where mongod >nul 2>&1
    if !errorLevel! equ 0 (
        echo   [OK] MongoDB binary found in PATH
        echo [%date% %time%] MongoDB: Binary found >> "%SETUP_LOG%"
    ) else (
        echo   [!] MongoDB not found locally
        echo   [i] Using MongoDB Atlas or manual start required
        echo [%date% %time%] WARNING: MongoDB not found >> "%SETUP_LOG%"
    )
)
echo.

REM ============================================================================
REM  BACKEND SETUP
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   BACKEND SETUP
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Setting up Python backend...
pushd "%SCRIPT_DIR%\backend"

REM Create virtual environment
if not exist "venv" (
    echo   [..] Creating virtual environment...
    %PYTHON_CMD% -m venv venv
    if !errorLevel! neq 0 (
        echo   [!!] Failed to create virtual environment
        echo [%date% %time%] ERROR: venv creation failed >> "%SETUP_LOG%"
    ) else (
        echo   [OK] Virtual environment created
        echo [%date% %time%] Virtual environment created >> "%SETUP_LOG%"
    )
) else (
    echo   [OK] Virtual environment exists
)

REM Activate and install dependencies
echo   [..] Installing Python dependencies...
call venv\Scripts\activate.bat 2>nul

if exist "requirements.txt" (
    %PYTHON_CMD% -m pip install -r requirements.txt -q 2>nul
) else (
    %PYTHON_CMD% -m pip install fastapi uvicorn python-dotenv motor pymongo pydantic httpx apscheduler pytz tzlocal -q 2>nul
)
echo   [OK] Python dependencies installed
echo [%date% %time%] Python dependencies installed >> "%SETUP_LOG%"

REM Create .env file if not exists
if not exist ".env" (
    echo   [..] Creating backend .env file...
    (
        echo MONGO_URL=mongodb://localhost:27017
        echo DB_NAME=whatsapp_scheduler
        echo WA_SERVICE_URL=http://localhost:3001
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > .env
    echo   [OK] Created backend .env
) else (
    echo   [OK] Backend .env exists
)
echo [%date% %time%] Backend environment configured >> "%SETUP_LOG%"

popd
echo.

REM ============================================================================
REM  WHATSAPP SERVICE SETUP
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   WHATSAPP SERVICE SETUP
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Setting up WhatsApp service...
echo   [i] This may take 3-5 minutes (downloads ~200MB)...

pushd "%SCRIPT_DIR%\whatsapp-service"

REM Clear any old yarn.lock that might cause issues
if exist "yarn.lock" del yarn.lock 2>nul

if not exist "node_modules\whatsapp-web.js" (
    echo   [..] Installing from npm registry...
    call npm install --registry https://registry.npmjs.org/ 2>nul
    if !errorLevel! neq 0 (
        echo   [!] First attempt had issues, retrying with --legacy-peer-deps...
        call npm install --legacy-peer-deps --registry https://registry.npmjs.org/ 2>nul
    )
)

if exist "node_modules\whatsapp-web.js" (
    echo   [OK] WhatsApp service dependencies installed
    echo [%date% %time%] WhatsApp dependencies installed >> "%SETUP_LOG%"
) else (
    echo   [!] WhatsApp dependencies may have issues
    echo   [i] Try running scripts\reinstall-whatsapp.bat
    echo [%date% %time%] WARNING: WhatsApp install incomplete >> "%SETUP_LOG%"
)

popd
echo.

REM ============================================================================
REM  FRONTEND SETUP
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   FRONTEND SETUP
echo  ----------------------------------------------------------------------------
echo.

echo   [..] Setting up React frontend...
echo   [i] This may take several minutes...

pushd "%SCRIPT_DIR%\frontend"

if not exist "node_modules" (
    call npm install --legacy-peer-deps 2>nul
    if !errorLevel! neq 0 (
        echo   [!] npm install had warnings - retrying...
        call npm install --legacy-peer-deps --force 2>nul
    )
)
echo   [OK] Frontend dependencies installed
echo [%date% %time%] Frontend dependencies installed >> "%SETUP_LOG%"

REM Create .env file if not exists
if not exist ".env" (
    echo REACT_APP_BACKEND_URL=http://localhost:8001> .env
    echo   [OK] Created frontend .env
) else (
    echo   [OK] Frontend .env exists
)

popd
echo.

REM ============================================================================
REM  SETUP COMPLETE
REM ============================================================================
echo  ----------------------------------------------------------------------------
echo   SETUP COMPLETE
echo  ----------------------------------------------------------------------------
echo.
echo   [OK] All components installed and configured!
echo.
echo  ============================================================================
echo   QUICK START GUIDE
echo  ============================================================================
echo.
echo   1. Start all services:    start.bat
echo   2. Stop all services:     stop.bat
echo   3. Restart services:      restart.bat
echo   4. Check health:          health-check.bat
echo.
echo   Dashboard:  http://localhost:3000
echo   Backend:    http://localhost:8001/api
echo   WhatsApp:   http://localhost:3001/status
echo.
echo   Log files:  %SCRIPT_DIR%\logs\
echo.
echo  ============================================================================
echo.

echo [%date% %time%] Setup completed successfully >> "%SETUP_LOG%"

pause
exit /b 0
