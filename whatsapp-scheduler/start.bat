@echo off
REM ================================================
REM WhatsApp Scheduler - Start Script
REM ================================================

title WhatsApp Scheduler - Launcher

echo ================================================
echo  WhatsApp Scheduler - Starting Services
echo ================================================
echo.

REM Get the directory where the script is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM ================================================
REM Check if setup was done - check for venv OR global install
REM ================================================
set USE_VENV=0
if exist "backend\venv" (
    set USE_VENV=1
    echo [Setup] Virtual environment found
) else (
    REM Check if fastapi is installed globally
    python -c "import fastapi" >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Setup not complete. Please run setup.bat first.
        pause
        exit /b 1
    )
    echo [Setup] Global installation found
)
echo.

REM ================================================
REM Start MongoDB if not running
REM ================================================
echo [1/4] Checking MongoDB...

tasklist /FI "IMAGENAME eq mongod.exe" 2>NUL | find /I /N "mongod.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo   [OK] MongoDB is already running
) else (
    echo   Starting MongoDB...
    if not exist "C:\data\db" mkdir "C:\data\db"
    start "MongoDB" /min mongod --dbpath "C:\data\db" 2>logs\mongodb.log
    timeout /t 3 /nobreak >nul
    echo   [OK] MongoDB started
)
echo.

REM ================================================
REM Start WhatsApp Service
REM ================================================
echo [2/4] Starting WhatsApp Service...
echo   Logs: logs\whatsapp.log

cd whatsapp-service
start "WhatsApp-Service" cmd /c "node index.js > ..\logs\whatsapp.log 2>&1"
cd ..
timeout /t 3 /nobreak >nul
echo   [OK] WhatsApp Service started on port 3001
echo.

REM ================================================
REM Start Backend
REM ================================================
echo [3/4] Starting Backend API...
echo   Logs: logs\backend.log

cd backend
if %USE_VENV%==1 (
    start "Backend-API" cmd /c "call venv\Scripts\activate.bat && python -m uvicorn server:app --host 0.0.0.0 --port 8001 > ..\logs\backend.log 2>&1"
) else (
    start "Backend-API" cmd /c "python -m uvicorn server:app --host 0.0.0.0 --port 8001 > ..\logs\backend.log 2>&1"
)
cd ..
timeout /t 5 /nobreak >nul
echo   [OK] Backend started on port 8001
echo.

REM ================================================
REM Start Frontend
REM ================================================
echo [4/4] Starting Frontend...
echo   Logs: logs\frontend.log
echo   Note: First start may take 30-60 seconds to compile...

cd frontend
start "Frontend-React" cmd /c "set BROWSER=none && npm start > ..\logs\frontend.log 2>&1"
cd ..
echo   [..] Frontend starting on port 3000
echo.

REM ================================================
REM Wait for frontend to be ready
REM ================================================
echo Waiting for frontend to compile (this may take a minute)...
set ATTEMPTS=0

:wait_loop
timeout /t 5 /nobreak >nul
set /a ATTEMPTS+=1

REM Check if frontend is responding
curl -s http://localhost:3000 >nul 2>&1
if %ERRORLEVEL%==0 (
    goto frontend_ready
)

if %ATTEMPTS% LSS 12 (
    echo   Still waiting... (%ATTEMPTS%/12)
    goto wait_loop
)

echo.
echo   [!] Frontend may still be starting...
echo   [!] Check logs\frontend.log for details
echo.

:frontend_ready
echo.
echo ================================================
echo  All services started!
echo ================================================
echo.
echo   Dashboard:  http://localhost:3000
echo   Backend:    http://localhost:8001/api
echo   WhatsApp:   http://localhost:3001/status
echo.
echo   Log files in: %SCRIPT_DIR%logs\
echo.
echo ================================================
echo.
echo Opening browser...
start http://localhost:3000

echo.
echo Press any key to stop all services and exit...
pause >nul

REM ================================================
REM Stop Services
REM ================================================
echo.
echo Stopping services...

taskkill /FI "WINDOWTITLE eq WhatsApp-Service*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Backend-API*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Frontend-React*" /F >nul 2>&1

echo Done!
