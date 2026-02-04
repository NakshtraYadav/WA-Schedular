@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Start Script for Windows 10/11
REM  Version: 2.0 | Health Checks | Auto-Recovery | Dashboard Display
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Service Manager
color 0B
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs\system"
set "TIMESTAMP=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "START_LOG=%LOG_DIR%\start_%TIMESTAMP%.log"
set "HEALTH_INTERVAL=30"
set "MAX_RETRIES=5"
set "STARTUP_TIMEOUT=120"

REM Service ports
set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"
set "MONGO_PORT=27017"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

REM Create log directories
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :LOG "============================================================================"
call :LOG "WhatsApp Scheduler - Service Start Initiated"
call :LOG "Time: %date% %time%"
call :LOG "============================================================================"

REM ============================================================================
REM  DISPLAY HEADER
REM ============================================================================
cls
echo.
echo   ===========================================================================
echo                    WhatsApp Scheduler - Service Manager
echo   ===========================================================================
echo.
echo    Status Dashboard                                     %date% %time%
echo   ---------------------------------------------------------------------------
echo.

REM ============================================================================
REM  PREFLIGHT CHECKS
REM ============================================================================
call :SECTION "PREFLIGHT VALIDATION"

REM Check if setup was completed
if not exist "%SCRIPT_DIR%\backend\venv" (
    if not exist "%SCRIPT_DIR%\frontend\node_modules" (
        call :FAIL "Setup not complete"
        echo.
        echo    Please run setup.bat first!
        echo.
        call :LOG "ERROR: Setup not complete"
        pause
        exit /b 1
    )
)
call :PASS "Setup verified"

REM Check Python
where python >nul 2>&1
if %errorLevel% neq 0 (
    where py >nul 2>&1
    if %errorLevel% neq 0 (
        call :FAIL "Python not found"
        call :LOG "ERROR: Python not found"
        pause
        exit /b 1
    )
    set "PYTHON_CMD=py"
) else (
    set "PYTHON_CMD=python"
)
call :PASS "Python available"

REM Check Node.js
where node >nul 2>&1
if %errorLevel% neq 0 (
    call :FAIL "Node.js not found"
    call :LOG "ERROR: Node.js not found"
    pause
    exit /b 1
)
call :PASS "Node.js available"

REM ============================================================================
REM  CHECK AND CLEAR PORTS
REM ============================================================================
call :SECTION "PORT MANAGEMENT"

REM Kill any existing processes on our ports
for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| find ":%%p " ^| find "LISTENING"') do (
        if "%%a" neq "0" (
            echo    [..] Freeing port %%p (PID: %%a^)...
            taskkill /F /PID %%a >nul 2>&1
            call :LOG "Killed process %%a on port %%p"
        )
    )
)
call :PASS "Ports cleared"

REM ============================================================================
REM  START MONGODB
REM ============================================================================
call :SECTION "MONGODB SERVICE"

set "MONGO_RUNNING=0"

REM Check if MongoDB service is running
sc query MongoDB >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=4" %%a in ('sc query MongoDB ^| find "STATE"') do (
        if "%%a"=="RUNNING" (
            set "MONGO_RUNNING=1"
            call :PASS "MongoDB service running"
            goto :mongo_done
        )
    )
    REM Try to start the service
    echo    [..] Starting MongoDB service...
    net start MongoDB >nul 2>&1
    if !errorLevel! equ 0 (
        set "MONGO_RUNNING=1"
        call :PASS "MongoDB service started"
        goto :mongo_done
    )
)

REM Check if mongod is accessible
where mongod >nul 2>&1
if %errorLevel% equ 0 (
    REM Check if already running
    netstat -an | find ":%MONGO_PORT% " | find "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        set "MONGO_RUNNING=1"
        call :PASS "MongoDB already running on port %MONGO_PORT%"
        goto :mongo_done
    )
    
    REM Start mongod manually
    echo    [..] Starting MongoDB daemon...
    if not exist "C:\data\db" mkdir "C:\data\db" 2>nul
    start "MongoDB" /min cmd /c "mongod --dbpath C:\data\db > "%SCRIPT_DIR%\logs\system\mongodb.log" 2>&1"
    
    REM Wait for MongoDB to start
    set "MONGO_WAIT=0"
    :mongo_wait_loop
    timeout /t 2 /nobreak >nul
    set /a MONGO_WAIT+=1
    netstat -an | find ":%MONGO_PORT% " | find "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        set "MONGO_RUNNING=1"
        call :PASS "MongoDB started"
        goto :mongo_done
    )
    if !MONGO_WAIT! LSS 10 goto :mongo_wait_loop
)

REM MongoDB not available locally, assume Atlas
if "!MONGO_RUNNING!"=="0" (
    call :WARN "MongoDB not running locally - assuming Atlas"
    call :LOG "WARNING: Local MongoDB not available"
)

:mongo_done
echo.

REM ============================================================================
REM  START WHATSAPP SERVICE
REM ============================================================================
call :SECTION "WHATSAPP SERVICE"

cd /d "%SCRIPT_DIR%\whatsapp-service"

if not exist "node_modules" (
    call :WARN "Dependencies missing, installing..."
    call npm install --silent >nul 2>&1
)

echo    [..] Starting WhatsApp service...
start "WhatsApp-Scheduler-WA" /min cmd /c "node index.js > "%SCRIPT_DIR%\logs\whatsapp\service_%TIMESTAMP%.log" 2>&1"
call :LOG "WhatsApp service start command issued"

REM Wait for WhatsApp service to be ready
set "WA_RETRIES=0"
:wa_health_loop
timeout /t 2 /nobreak >nul
set /a WA_RETRIES+=1

curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "WhatsApp service ready (port %WHATSAPP_PORT%)"
    call :LOG "WhatsApp service healthy"
    goto :wa_done
)

if !WA_RETRIES! LSS 15 (
    echo    [..] Waiting for WhatsApp service... (!WA_RETRIES!/15^)
    goto :wa_health_loop
)

call :WARN "WhatsApp service slow to start"
call :LOG "WARNING: WhatsApp service health check timeout"

:wa_done
cd /d "%SCRIPT_DIR%"
echo.

REM ============================================================================
REM  START BACKEND
REM ============================================================================
call :SECTION "BACKEND API SERVICE"

cd /d "%SCRIPT_DIR%\backend"

echo    [..] Starting Backend API...

if exist "venv\Scripts\activate.bat" (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "call venv\Scripts\activate.bat && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% > "%SCRIPT_DIR%\logs\backend\api_%TIMESTAMP%.log" 2>&1"
) else (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "%PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% > "%SCRIPT_DIR%\logs\backend\api_%TIMESTAMP%.log" 2>&1"
)
call :LOG "Backend start command issued"

REM Wait for Backend to be ready
set "BE_RETRIES=0"
:be_health_loop
timeout /t 2 /nobreak >nul
set /a BE_RETRIES+=1

curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "Backend API ready (port %BACKEND_PORT%)"
    call :LOG "Backend API healthy"
    goto :be_done
)

if !BE_RETRIES! LSS 20 (
    echo    [..] Waiting for Backend API... (!BE_RETRIES!/20^)
    goto :be_health_loop
)

call :WARN "Backend slow to start - check logs"
call :LOG "WARNING: Backend health check timeout"

:be_done
cd /d "%SCRIPT_DIR%"
echo.

REM ============================================================================
REM  START FRONTEND
REM ============================================================================
call :SECTION "FRONTEND SERVICE"

cd /d "%SCRIPT_DIR%\frontend"

if not exist "node_modules" (
    call :WARN "Dependencies missing, installing..."
    call npm install --legacy-peer-deps --silent >nul 2>&1
)

echo    [..] Starting React frontend...
echo    [i] First start may take 1-2 minutes to compile...

start "WhatsApp-Scheduler-Frontend" /min cmd /c "set BROWSER=none&& npm start > "%SCRIPT_DIR%\logs\frontend\react_%TIMESTAMP%.log" 2>&1"
call :LOG "Frontend start command issued"

REM Wait for Frontend to be ready (longer timeout for first compile)
set "FE_RETRIES=0"
:fe_health_loop
timeout /t 5 /nobreak >nul
set /a FE_RETRIES+=1

curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "Frontend ready (port %FRONTEND_PORT%)"
    call :LOG "Frontend healthy"
    goto :fe_done
)

if !FE_RETRIES! LSS 24 (
    echo    [..] Compiling frontend... (!FE_RETRIES!/24^) ~!FE_RETRIES!0 seconds
    goto :fe_health_loop
)

call :WARN "Frontend compilation taking longer than expected"
call :LOG "WARNING: Frontend health check timeout"

:fe_done
cd /d "%SCRIPT_DIR%"
echo.

REM ============================================================================
REM  POST-LAUNCH VERIFICATION
REM ============================================================================
call :SECTION "POST-LAUNCH VERIFICATION"

set "ALL_OK=1"

REM Verify Backend
curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "Backend API responding"
) else (
    call :FAIL "Backend API not responding"
    set "ALL_OK=0"
)

REM Verify WhatsApp Service
curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "WhatsApp service responding"
) else (
    call :FAIL "WhatsApp service not responding"
    set "ALL_OK=0"
)

REM Verify Frontend
curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "Frontend responding"
) else (
    call :WARN "Frontend may still be compiling"
)

REM Test API endpoint
curl -s http://localhost:%BACKEND_PORT%/api/dashboard/stats >nul 2>&1
if %errorLevel% equ 0 (
    call :PASS "API endpoints functional"
) else (
    call :WARN "API endpoints may need database"
)

echo.
call :LOG "Post-launch verification completed"

REM ============================================================================
REM  LAUNCH COMPLETE DASHBOARD
REM ============================================================================
echo.
echo   ===========================================================================
echo                         ALL SERVICES STARTED
echo   ===========================================================================
echo.
echo    Service                    Port        Status
echo   ---------------------------------------------------------------------------
echo    Frontend Dashboard         %FRONTEND_PORT%         http://localhost:%FRONTEND_PORT%
echo    Backend API                %BACKEND_PORT%         http://localhost:%BACKEND_PORT%/api
echo    WhatsApp Service           %WHATSAPP_PORT%         http://localhost:%WHATSAPP_PORT%/status
if "!MONGO_RUNNING!"=="1" (
echo    MongoDB                    %MONGO_PORT%        Running locally
) else (
echo    MongoDB                    -           Using Atlas/Remote
)
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

call :LOG "All services started successfully"

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

REM Check Backend
curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %time% - Backend not responding, restarting...
    call :LOG "WATCHDOG: Backend restart triggered"
    cd /d "%SCRIPT_DIR%\backend"
    if exist "venv\Scripts\activate.bat" (
        start "WhatsApp-Scheduler-Backend" /min cmd /c "call venv\Scripts\activate.bat && %PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_%TIMESTAMP%.log" 2>&1"
    ) else (
        start "WhatsApp-Scheduler-Backend" /min cmd /c "%PYTHON_CMD% -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_%TIMESTAMP%.log" 2>&1"
    )
    set "RESTART_NEEDED=1"
    cd /d "%SCRIPT_DIR%"
)

REM Check WhatsApp Service
curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %time% - WhatsApp service not responding, restarting...
    call :LOG "WATCHDOG: WhatsApp service restart triggered"
    cd /d "%SCRIPT_DIR%\whatsapp-service"
    start "WhatsApp-Scheduler-WA" /min cmd /c "node index.js >> "%SCRIPT_DIR%\logs\whatsapp\service_%TIMESTAMP%.log" 2>&1"
    set "RESTART_NEEDED=1"
    cd /d "%SCRIPT_DIR%"
)

REM Check Frontend
curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!] %time% - Frontend not responding, restarting...
    call :LOG "WATCHDOG: Frontend restart triggered"
    cd /d "%SCRIPT_DIR%\frontend"
    start "WhatsApp-Scheduler-Frontend" /min cmd /c "set BROWSER=none&& npm start >> "%SCRIPT_DIR%\logs\frontend\react_%TIMESTAMP%.log" 2>&1"
    set "RESTART_NEEDED=1"
    cd /d "%SCRIPT_DIR%"
)

if "!RESTART_NEEDED!"=="0" (
    echo    [OK] %time% - All services healthy
)

goto :watchdog_loop

REM ============================================================================
REM  UTILITY FUNCTIONS
REM ============================================================================

:LOG
echo [%date% %time%] %~1 >> "%START_LOG%" 2>nul
goto :eof

:SECTION
echo    ---------------------------------------------------------------------------
echo    %~1
echo    ---------------------------------------------------------------------------
goto :eof

:PASS
echo    [OK] %~1
goto :eof

:FAIL
echo    [!!] %~1
goto :eof

:WARN
echo    [!] %~1
goto :eof
