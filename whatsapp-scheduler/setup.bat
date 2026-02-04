@echo off
REM ================================================
REM WhatsApp Scheduler - Windows Setup Script
REM ================================================

echo ================================================
echo  WhatsApp Scheduler - Setup Script
echo ================================================
echo.

REM ================================================
REM Step 1: Check Prerequisites
REM ================================================
echo [Step 1/6] Checking prerequisites...
echo.

REM Check Node.js
where node >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: Node.js is not installed!
    echo.
    echo Please install Node.js from: https://nodejs.org/
    echo Download the LTS version and run the installer.
    echo After installation, restart this script.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
echo   [OK] Node.js %NODE_VERSION%

REM Check Python
where python >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: Python is not installed!
    echo.
    echo Please install Python from: https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    echo After installation, restart this script.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo   [OK] %PYTHON_VERSION%

REM Check MongoDB
echo   [..] Checking MongoDB...
where mongod >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo WARNING: MongoDB is not found in PATH.
    echo.
    echo Option 1: Install MongoDB Community Server
    echo   Download from: https://www.mongodb.com/try/download/community
    echo.
    echo Option 2: Use MongoDB Atlas Cloud
    echo   Sign up at: https://www.mongodb.com/cloud/atlas
    echo   Then update MONGO_URL in backend\.env
    echo.
    echo Press any key to continue anyway...
    pause >nul
) else (
    echo   [OK] MongoDB found
)

echo.
echo [Step 1/6] Prerequisites check complete!
echo.

REM ================================================
REM Step 2: Create Directory Structure
REM ================================================
echo [Step 2/6] Setting up directories...

if not exist "backend" mkdir backend
if not exist "frontend" mkdir frontend
if not exist "whatsapp-service" mkdir whatsapp-service
if not exist "logs" mkdir logs

echo   [OK] Directories created
echo.

REM ================================================
REM Step 3: Setup Backend - Choose Installation Type
REM ================================================
echo [Step 3/6] Setting up Python backend...
echo.
echo Choose installation method:
echo   [1] Virtual environment (recommended - isolated)
echo   [2] Direct install (installs packages globally)
echo.
set /p INSTALL_CHOICE="Enter choice (1 or 2): "

cd backend

if "%INSTALL_CHOICE%"=="1" (
    echo.
    echo   Using virtual environment...
    REM Create virtual environment if not exists
    if not exist "venv" (
        echo   Creating virtual environment...
        python -m venv venv
    )
    REM Activate and install dependencies
    echo   Installing Python dependencies...
    call venv\Scripts\activate.bat
    pip install --quiet fastapi uvicorn python-dotenv motor pymongo pydantic httpx apscheduler pytz tzlocal python-telegram-bot
) else (
    echo.
    echo   Installing packages globally...
    pip install --quiet fastapi uvicorn python-dotenv motor pymongo pydantic httpx apscheduler pytz tzlocal python-telegram-bot
)

REM Create .env file if not exists
if not exist ".env" (
    echo   Creating backend .env file...
    echo MONGO_URL=mongodb://localhost:27017> .env
    echo DB_NAME=whatsapp_scheduler>> .env
    echo WA_SERVICE_URL=http://localhost:3001>> .env
)

cd ..
echo   [OK] Backend setup complete
echo.

REM ================================================
REM Step 4: Setup WhatsApp Service
REM ================================================
echo [Step 4/6] Setting up WhatsApp service...
echo   This installs Puppeteer with Chromium (may take a few minutes)...

cd whatsapp-service

REM Clean install npm dependencies
if exist "node_modules" (
    echo   Updating dependencies...
) else (
    echo   Installing Node.js dependencies...
)
call npm install --silent
if errorlevel 1 (
    echo   [!] Warning: npm install had issues, trying with --legacy-peer-deps
    call npm install --legacy-peer-deps --silent
)

cd ..
echo   [OK] WhatsApp service setup complete
echo.

REM ================================================
REM Step 5: Setup Frontend
REM ================================================
echo [Step 5/6] Setting up React frontend...

cd frontend

REM Install npm dependencies
if not exist "node_modules" (
    echo   Installing frontend dependencies...
    echo   This may take a few minutes...
    call npm install --legacy-peer-deps
    REM Fix ajv module issue for Node.js 22+
    call npm install ajv@^8.12.0 --legacy-peer-deps --silent
)

REM Create .env file if not exists
if not exist ".env" (
    echo   Creating frontend .env file...
    echo REACT_APP_BACKEND_URL=http://localhost:8001> .env
)

cd ..
echo   [OK] Frontend setup complete
echo.

REM ================================================
REM Step 6: Final Instructions
REM ================================================
echo [Step 6/6] Setup complete!
echo.
echo ================================================
echo  SETUP COMPLETE!
echo ================================================
echo.
if "%INSTALL_CHOICE%"=="1" (
    echo Installation type: Virtual Environment
    echo To activate manually: cd backend ^&^& venv\Scripts\activate
) else (
    echo Installation type: Global
)
echo.
echo To start the application, run: start.bat
echo.
echo Make sure MongoDB is running before starting!
echo.
echo ================================================
echo.
pause
