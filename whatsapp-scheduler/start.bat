@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Start Script for Windows 10/11
REM  Version: 2.1 | Fixed path handling for spaces
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Service Manager
color 0B
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs\system"

REM Create timestamp
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,8%_%dt:~8,6%"
set "START_LOG=%LOG_DIR%\start_%TIMESTAMP%.log"

set "HEALTH_INTERVAL=30"

REM Service ports
set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"
set "MONGO_PORT=27017"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

REM Create log directories if missing
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%SCRIPT_DIR%\logs\backend" mkdir "%SCRIPT_DIR%\logs\backend"
if not exist "%SCRIPT_DIR%\logs\frontend" mkdir "%SCRIPT_DIR%\logs\frontend"
if not exist "%SCRIPT_DIR%\logs\whatsapp" mkdir "%SCRIPT_DIR%\logs\whatsapp"

echo [%date% %time%] Service Start Initiated > "%START_LOG%"

REM ============================================================================
REM  DISPLAY HEADER
REM ============================================================================
cls
echo.
echo   ===========================================================================
echo                    WhatsApp Scheduler - Service Manager
echo   ===========================================================================
echo.
echo    Working Directory: %SCRIPT_DIR%
echo    Status Dashboard                                     %date% %time%
echo   ---------------------------------------------------------------------------
echo.

REM ============================================================================
REM  PREFLIGHT CHECKS
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    PREFLIGHT VALIDATION
echo   ---------------------------------------------------------------------------
echo.

REM Check if setup was completed
if not exist "%SCRIPT_DIR%\backend\venv" (
    if not exist "%SCRIPT_DIR%\frontend\node_modules" (
        echo    [!!] Setup not complete - run setup.bat first
        echo.
        echo [%date% %time%] ERROR: Setup not complete >> "%START_LOG%"
        pause
        exit /b 1
    )
)
echo    [OK] Setup verified

REM Check Python
set "PYTHON_CMD=python"
python --version >nul 2>&1
if %errorLevel% neq 0 (
    py --version >nul 2>&1
    if %errorLevel% neq 0 (
        echo    [!!] Python not found
        echo [%date% %time%] ERROR: Python not found >> "%START_LOG%"
        pause
        exit /b 1
    )
    set "PYTHON_CMD=py"
)
echo    [OK] Python available

REM Check Node.js
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!!] Node.js not found
    echo [%date% %time%] ERROR: Node.js not found >> "%START_LOG%"
    pause
    exit /b 1
)
echo    [OK] Node.js available
echo.

REM ============================================================================
REM  CHECK AND CLEAR PORTS
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    PORT MANAGEMENT
echo   ---------------------------------------------------------------------------
echo.

REM Kill any existing processes on our ports
for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        if "%%a" neq "0" (
            echo    [..] Freeing port %%p (PID: %%a^)...
            taskkill /F /PID %%a >nul 2>&1
            echo [%date% %time%] Killed PID %%a on port %%p >> "%START_LOG%"
        )
    )
)
echo    [OK] Ports cleared
echo.

REM ============================================================================
REM  START MONGODB
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    MONGODB SERVICE
echo   ---------------------------------------------------------------------------
echo.

set "MONGO_RUNNING=0"

REM Check if MongoDB service is running
sc query MongoDB >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=4" %%a in ('sc query MongoDB ^| find "STATE"') do (
        if "%%a"=="RUNNING" (
            set "MONGO_RUNNING=1"
            echo    [OK] MongoDB service running
            goto :mongo_done
        )
    )
    echo    [..] Starting MongoDB service...
    net start MongoDB >nul 2>&1
    if !errorLevel! equ 0 (
        set "MONGO_RUNNING=1"
        echo    [OK] MongoDB service started
        goto :mongo_done
    )
)

REM Check if already running on port
netstat -an 2>nul | findstr ":%MONGO_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    set "MONGO_RUNNING=1"
    echo    [OK] MongoDB already running on port %MONGO_PORT%
    goto :mongo_done
)

REM Try to start mongod manually
where mongod >nul 2>&1
if %errorLevel% equ 0 (
    echo    [..] Starting MongoDB daemon...
    if not exist "C:\data\db" mkdir "C:\data\db" 2>nul
    start "MongoDB" /min cmd /c "mongod --dbpath C:\data\db > "%SCRIPT_DIR%\logs\system\mongodb.log" 2>&1"
    timeout /t 3 /nobreak >nul
    set "MONGO_RUNNING=1"
    echo    [OK] MongoDB started
    goto :mongo_done
)

echo    [!] MongoDB not running locally - using Atlas or remote?
echo [%date% %time%] WARNING: Local MongoDB not available >> "%START_LOG%"

:mongo_done
echo.

REM ============================================================================
REM  START WHATSAPP SERVICE
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    WHATSAPP SERVICE (whatsapp-web.js@1.34.6)
echo   ---------------------------------------------------------------------------
echo.

echo    [..] Starting WhatsApp service...

set "WA_LOG=%SCRIPT_DIR%\logs\whatsapp\service_%TIMESTAMP%.log"
start "WhatsApp-Scheduler-WA" /min cmd /c "cd /d "%SCRIPT_DIR%\whatsapp-service" && node index.js > "%WA_LOG%" 2>&1"
echo [%date% %time%] WhatsApp service start command issued >> "%START_LOG%"

REM Wait for WhatsApp service
set "WA_RETRIES=0"
:wa_health_loop
timeout /t 2 /nobreak >nul
set /a WA_RETRIES+=1

curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% equ 0 (
    echo    [OK] WhatsApp service ready (port %WHATSAPP_PORT%)
    echo [%date% %time%] WhatsApp service healthy >> "%START_LOG%"
    goto :wa_done
)

if %WA_RETRIES% LSS 15 (
    echo    [..] Waiting for WhatsApp service... ^(%WA_RETRIES%/15^)
    goto :wa_health_loop
)

echo    [!] WhatsApp service slow to start
echo [%date% %time%] WARNING: WhatsApp health check timeout >> "%START_LOG%"

:wa_done
echo.

REM ============================================================================
REM  START BACKEND
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    BACKEND API SERVICE
echo   ---------------------------------------------------------------------------
echo.

echo    [..] Starting Backend API...

set "BE_LOG=%SCRIPT_DIR%\logs\backend\api_%TIMESTAMP%.log"

if exist "%SCRIPT_DIR%\backend\venv\Scripts\activate.bat" (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && call venv\Scripts\activate.bat && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% > "%BE_LOG%" 2>&1"
) else (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% > "%BE_LOG%" 2>&1"
)
echo [%date% %time%] Backend start command issued >> "%START_LOG%"

REM Wait for Backend with better error checking
set "BE_RETRIES=0"
:be_health_loop
timeout /t 3 /nobreak >nul
set /a BE_RETRIES+=1

REM First check if port is listening
netstat -an 2>nul | findstr ":%BACKEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% neq 0 (
    if %BE_RETRIES% GEQ 15 (
        echo    [!!] Backend failed to start - checking error log...
        if exist "%BE_LOG%" (
            echo    --- Last 10 lines of backend log ---
            powershell -Command "Get-Content '%BE_LOG%' -Tail 10" 2>nul
            echo    --- End of log ---
        )
        echo [%date% %time%] ERROR: Backend failed to start >> "%START_LOG%"
        goto :be_done
    )
    echo    [..] Waiting for Backend to start... ^(%BE_RETRIES%/15^)
    goto :be_health_loop
)

REM Port is listening, check API response
curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% equ 0 (
    echo    [OK] Backend API ready (port %BACKEND_PORT%)
    echo [%date% %time%] Backend API healthy >> "%START_LOG%"
    goto :be_done
)

if %BE_RETRIES% LSS 20 (
    echo    [..] Backend starting, waiting for API... ^(%BE_RETRIES%/20^)
    goto :be_health_loop
)

echo    [!] Backend port open but API not responding
echo [%date% %time%] WARNING: Backend API not responding >> "%START_LOG%"

:be_done
echo.

REM ============================================================================
REM  START FRONTEND
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    FRONTEND SERVICE
echo   ---------------------------------------------------------------------------
echo.

echo    [..] Starting React frontend...
echo    [i] First start may take 1-2 minutes to compile...

set "FE_LOG=%SCRIPT_DIR%\logs\frontend\react_%TIMESTAMP%.log"
start "WhatsApp-Scheduler-Frontend" /min cmd /c "cd /d "%SCRIPT_DIR%\frontend" && set BROWSER=none && npm start > "%FE_LOG%" 2>&1"
echo [%date% %time%] Frontend start command issued >> "%START_LOG%"

REM Wait for Frontend
set "FE_RETRIES=0"
:fe_health_loop
timeout /t 5 /nobreak >nul
set /a FE_RETRIES+=1

curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% equ 0 (
    echo    [OK] Frontend ready (port %FRONTEND_PORT%)
    echo [%date% %time%] Frontend healthy >> "%START_LOG%"
    goto :fe_done
)

if %FE_RETRIES% LSS 24 (
    echo    [..] Compiling frontend... ^(%FE_RETRIES%/24^) ~%FE_RETRIES%0 seconds
    goto :fe_health_loop
)

echo    [!] Frontend compilation taking longer than expected
echo [%date% %time%] WARNING: Frontend health check timeout >> "%START_LOG%"

:fe_done
echo.

REM ============================================================================
REM  LAUNCH COMPLETE
REM ============================================================================
echo.
echo   ===========================================================================
echo                         ALL SERVICES STARTED
echo   ===========================================================================
echo.
echo    Service                    Port        URL
echo   ---------------------------------------------------------------------------
echo    Frontend Dashboard         %FRONTEND_PORT%         http://localhost:%FRONTEND_PORT%
echo    Backend API                %BACKEND_PORT%         http://localhost:%BACKEND_PORT%/api
echo    WhatsApp Service           %WHATSAPP_PORT%         http://localhost:%WHATSAPP_PORT%/status
echo   ---------------------------------------------------------------------------
echo.
echo    Log Directory:  %SCRIPT_DIR%\logs\
echo.
echo   ===========================================================================
echo.

REM Open browser
echo    [i] Opening dashboard in browser...
start http://localhost:%FRONTEND_PORT%
echo.

echo [%date% %time%] All services started successfully >> "%START_LOG%"

REM ============================================================================
REM  WATCHDOG MODE
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    WATCHDOG MODE ACTIVE - Monitoring services every %HEALTH_INTERVAL%s
echo    Press CTRL+C to stop monitoring (services will continue running)
echo    Run stop.bat to stop all services
echo   ---------------------------------------------------------------------------
echo.

:watchdog_loop
timeout /t %HEALTH_INTERVAL% /nobreak >nul

set "RESTART_NEEDED=0"
set "STATUS_TIME=%time:~0,8%"

REM Check Backend
curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %STATUS_TIME% - Backend not responding, restarting...
    echo [%date% %time%] WATCHDOG: Backend restart triggered >> "%START_LOG%"
    
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%BACKEND_PORT% " ^| findstr "LISTENING"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    
    if exist "%SCRIPT_DIR%\backend\venv\Scripts\activate.bat" (
        start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && call venv\Scripts\activate.bat && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%BE_LOG%" 2>&1"
    ) else (
        start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%BE_LOG%" 2>&1"
    )
    set "RESTART_NEEDED=1"
)

REM Check WhatsApp Service
curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %STATUS_TIME% - WhatsApp service not responding, restarting...
    echo [%date% %time%] WATCHDOG: WhatsApp restart triggered >> "%START_LOG%"
    
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%WHATSAPP_PORT% " ^| findstr "LISTENING"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    
    start "WhatsApp-Scheduler-WA" /min cmd /c "cd /d "%SCRIPT_DIR%\whatsapp-service" && node index.js >> "%WA_LOG%" 2>&1"
    set "RESTART_NEEDED=1"
)

REM Check Frontend
curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %STATUS_TIME% - Frontend not responding, restarting...
    echo [%date% %time%] WATCHDOG: Frontend restart triggered >> "%START_LOG%"
    
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%FRONTEND_PORT% " ^| findstr "LISTENING"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    
    start "WhatsApp-Scheduler-Frontend" /min cmd /c "cd /d "%SCRIPT_DIR%\frontend" && set BROWSER=none && npm start >> "%FE_LOG%" 2>&1"
    set "RESTART_NEEDED=1"
)

if "%RESTART_NEEDED%"=="0" (
    echo    [OK] %STATUS_TIME% - All services healthy
)

goto :watchdog_loop
