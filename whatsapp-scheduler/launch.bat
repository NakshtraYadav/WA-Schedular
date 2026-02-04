@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Silent Background Launcher
REM  Version: 3.0 | Runs all services in background without extra windows
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Control Panel
color 0B
mode con: cols=100 lines=40

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs"
set "PID_DIR=%SCRIPT_DIR%\.pids"

REM Get timestamp using PowerShell (WMIC is deprecated in Windows 11)
for /f %%a in ('powershell -Command "Get-Date -Format \"yyyyMMdd_HHmmss\""') do set "TIMESTAMP=%%a"

REM Service ports
set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

REM Create directories
if not exist "%LOG_DIR%\backend" mkdir "%LOG_DIR%\backend"
if not exist "%LOG_DIR%\frontend" mkdir "%LOG_DIR%\frontend"
if not exist "%LOG_DIR%\whatsapp" mkdir "%LOG_DIR%\whatsapp"
if not exist "%LOG_DIR%\system" mkdir "%LOG_DIR%\system"
if not exist "%PID_DIR%" mkdir "%PID_DIR%"


REM ============================================================================
REM  HEADER
REM ============================================================================
cls
echo.
echo   ===========================================================================
echo         WhatsApp Scheduler - Silent Background Launcher v3.0
echo   ===========================================================================
echo.
echo    All services run in background - no extra windows!
echo    Monitor everything from the web dashboard.
echo.
echo   ===========================================================================
echo.

REM ============================================================================
REM  PREFLIGHT
REM ============================================================================
echo    [..] Running preflight checks...

REM Check Python
set "PYTHON_CMD=python"
python --version >nul 2>&1
if %errorLevel% neq 0 (
    py --version >nul 2>&1
    if %errorLevel% neq 0 (
        echo    [!!] Python not found
        pause
        exit /b 1
    )
    set "PYTHON_CMD=py"
)
echo    [OK] Python found

REM Check Node
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!!] Node.js not found
    pause
    exit /b 1
)
echo    [OK] Node.js found

echo.

REM ============================================================================
REM  STOP ANY EXISTING SERVICES
REM ============================================================================
echo    [..] Stopping any existing services...

for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        if "%%a" neq "0" (
            taskkill /F /PID %%a >nul 2>&1
        )
    )
)

REM Also kill by window title if any exist
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-*" /F >nul 2>&1

timeout /t 2 /nobreak >nul
echo    [OK] Ports cleared
echo.

REM ============================================================================
REM  START MONGODB (if service exists)
REM ============================================================================
echo    [..] Checking MongoDB...

sc query MongoDB >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=4" %%a in ('sc query MongoDB ^| find "STATE"') do (
        if "%%a" neq "RUNNING" (
            net start MongoDB >nul 2>&1
        )
    )
    echo    [OK] MongoDB service active
) else (
    netstat -an | findstr ":27017 " | findstr "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo    [OK] MongoDB running on port 27017
    ) else (
        echo    [!] MongoDB not detected - using Atlas or start manually
    )
)
echo.

REM ============================================================================
REM  START WHATSAPP SERVICE (Background)
REM ============================================================================
echo    [..] Starting WhatsApp service (background)...

set "WA_LOG=%LOG_DIR%\whatsapp\service_%TIMESTAMP%.log"

REM Use PowerShell to start process in background without window
powershell -Command "Start-Process -FilePath 'node' -ArgumentList 'index.js' -WorkingDirectory '%SCRIPT_DIR%\whatsapp-service' -WindowStyle Hidden -RedirectStandardOutput '%WA_LOG%' -RedirectStandardError '%WA_LOG%'" 2>nul

if %errorLevel% neq 0 (
    REM Fallback: use start /B for older systems
    start /B cmd /c "cd /d "%SCRIPT_DIR%\whatsapp-service" && node index.js > "%WA_LOG%" 2>&1"
)

echo    [OK] WhatsApp service starting...
echo    [i] Log: %WA_LOG%

REM Wait for WhatsApp
set "WA_READY=0"
for /l %%i in (1,1,15) do (
    timeout /t 2 /nobreak >nul
    curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
    if !errorLevel! equ 0 (
        set "WA_READY=1"
        goto :wa_ready
    )
    echo    [..] Waiting for WhatsApp service... ^(%%i/15^)
)
:wa_ready
if "%WA_READY%"=="1" (
    echo    [OK] WhatsApp service ready on port %WHATSAPP_PORT%
) else (
    echo    [!] WhatsApp service slow - check logs
)
echo.

REM ============================================================================
REM  START BACKEND (Background)
REM ============================================================================
echo    [..] Starting Backend API (background)...

set "BE_LOG=%LOG_DIR%\backend\api_%TIMESTAMP%.log"

REM Activate venv and start uvicorn
if exist "%SCRIPT_DIR%\backend\venv\Scripts\python.exe" (
    powershell -Command "Start-Process -FilePath '%SCRIPT_DIR%\backend\venv\Scripts\python.exe' -ArgumentList '-m','uvicorn','server:app','--host','0.0.0.0','--port','%BACKEND_PORT%' -WorkingDirectory '%SCRIPT_DIR%\backend' -WindowStyle Hidden -RedirectStandardOutput '%BE_LOG%' -RedirectStandardError '%BE_LOG%'" 2>nul
) else (
    powershell -Command "Start-Process -FilePath '%PYTHON_CMD%' -ArgumentList '-m','uvicorn','server:app','--host','0.0.0.0','--port','%BACKEND_PORT%' -WorkingDirectory '%SCRIPT_DIR%\backend' -WindowStyle Hidden -RedirectStandardOutput '%BE_LOG%' -RedirectStandardError '%BE_LOG%'" 2>nul
)

echo    [OK] Backend starting...
echo    [i] Log: %BE_LOG%

REM Wait for Backend
set "BE_READY=0"
for /l %%i in (1,1,15) do (
    timeout /t 2 /nobreak >nul
    curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
    if !errorLevel! equ 0 (
        set "BE_READY=1"
        goto :be_ready
    )
    echo    [..] Waiting for Backend API... ^(%%i/15^)
)
:be_ready
if "%BE_READY%"=="1" (
    echo    [OK] Backend API ready on port %BACKEND_PORT%
) else (
    echo    [!] Backend slow - check logs
)
echo.

REM ============================================================================
REM  START FRONTEND (Background)
REM ============================================================================
echo    [..] Starting Frontend (background)...
echo    [i] First start compiles React - may take 1-2 minutes...

set "FE_LOG=%LOG_DIR%\frontend\react_%TIMESTAMP%.log"

REM Set BROWSER=none to prevent auto-opening browser
powershell -Command "$env:BROWSER='none'; Start-Process -FilePath 'npm' -ArgumentList 'start' -WorkingDirectory '%SCRIPT_DIR%\frontend' -WindowStyle Hidden -RedirectStandardOutput '%FE_LOG%' -RedirectStandardError '%FE_LOG%'" 2>nul

echo    [OK] Frontend starting...
echo    [i] Log: %FE_LOG%

REM Wait for Frontend (longer timeout for compilation)
set "FE_READY=0"
for /l %%i in (1,1,30) do (
    timeout /t 4 /nobreak >nul
    curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
    if !errorLevel! equ 0 (
        set "FE_READY=1"
        goto :fe_ready
    )
    echo    [..] Compiling frontend... ^(%%i/30^) ~!%%i!0 seconds
)
:fe_ready
if "%FE_READY%"=="1" (
    echo    [OK] Frontend ready on port %FRONTEND_PORT%
) else (
    echo    [!] Frontend compilation slow - check logs
)
echo.

REM ============================================================================
REM  LAUNCH COMPLETE
REM ============================================================================
echo.
echo   ===========================================================================
echo                    ALL SERVICES STARTED (Background Mode)
echo   ===========================================================================
echo.
echo    Service                    Port        Status
echo   ---------------------------------------------------------------------------

REM Check final status
curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
if %errorLevel% equ 0 (
    echo    WhatsApp Service           %WHATSAPP_PORT%         [RUNNING]
) else (
    echo    WhatsApp Service           %WHATSAPP_PORT%         [STARTING...]
)

curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
if %errorLevel% equ 0 (
    echo    Backend API                %BACKEND_PORT%         [RUNNING]
) else (
    echo    Backend API                %BACKEND_PORT%         [STARTING...]
)

curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
if %errorLevel% equ 0 (
    echo    Frontend Dashboard         %FRONTEND_PORT%         [RUNNING]
) else (
    echo    Frontend Dashboard         %FRONTEND_PORT%         [COMPILING...]
)

echo   ---------------------------------------------------------------------------
echo.
echo    Dashboard:      http://localhost:%FRONTEND_PORT%
echo    Diagnostics:    http://localhost:%FRONTEND_PORT%/diagnostics
echo    API Health:     http://localhost:%BACKEND_PORT%/api/health
echo.
echo    All logs saved to: %LOG_DIR%\
echo.
echo   ===========================================================================
echo.

REM Open browser
echo    [i] Opening dashboard in browser...
start http://localhost:%FRONTEND_PORT%

echo.
echo    Press any key to open Diagnostics page, or close this window.
echo    Services will continue running in background.
echo.
pause >nul

start http://localhost:%FRONTEND_PORT%/diagnostics
exit /b 0
