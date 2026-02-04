@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Watchdog Service for Windows 10/11
REM  Version: 2.1 | Fixed path handling
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Watchdog
color 0D
mode con: cols=100 lines=40

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs\system"
set "WATCHDOG_LOG=%LOG_DIR%\watchdog.log"

set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"

set "CHECK_INTERVAL=30"
set "MAX_CONSECUTIVE_FAILURES=3"

REM Failure counters
set "FRONTEND_FAILURES=0"
set "BACKEND_FAILURES=0"
set "WHATSAPP_FAILURES=0"

REM Python command
set "PYTHON_CMD=python"
python --version >nul 2>&1
if %errorLevel% neq 0 (
    set "PYTHON_CMD=py"
)

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo [%date% %time%] Watchdog Service Started >> "%WATCHDOG_LOG%"
echo [%date% %time%] Check interval: %CHECK_INTERVAL% seconds >> "%WATCHDOG_LOG%"

REM ============================================================================
REM  DISPLAY
REM ============================================================================
cls
echo.
echo   ===========================================================================
echo              WhatsApp Scheduler - Watchdog Service
echo   ===========================================================================
echo.
echo    Monitoring services every %CHECK_INTERVAL% seconds...
echo    Max failures before restart: %MAX_CONSECUTIVE_FAILURES%
echo    Press CTRL+C to stop monitoring
echo.
echo   ---------------------------------------------------------------------------
echo.

REM ============================================================================
REM  WATCHDOG LOOP
REM ============================================================================
:watchdog_loop

set "CURRENT_TIME=%time:~0,8%"
set "STATUS_LINE=[%CURRENT_TIME%]"
set "RESTART_NEEDED=0"

REM ============================================================================
REM  CHECK BACKEND
REM ============================================================================
curl -s -o nul -w "" http://localhost:%BACKEND_PORT%/api/ --connect-timeout 5 >nul 2>&1
if %errorLevel% equ 0 (
    set "STATUS_LINE=!STATUS_LINE! Backend:OK"
    set "BACKEND_FAILURES=0"
) else (
    set /a BACKEND_FAILURES+=1
    set "STATUS_LINE=!STATUS_LINE! Backend:FAIL(!BACKEND_FAILURES!)"
    echo [%date% %time%] Backend health check failed (!BACKEND_FAILURES!) >> "%WATCHDOG_LOG%"
    
    if !BACKEND_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        echo.
        echo    [WATCHDOG] Restarting Backend API...
        echo [%date% %time%] Restarting Backend API >> "%WATCHDOG_LOG%"
        
        for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%BACKEND_PORT% " ^| findstr "LISTENING"') do (
            taskkill /F /PID %%a >nul 2>&1
        )
        timeout /t 2 /nobreak >nul
        
        if exist "%SCRIPT_DIR%\backend\venv\Scripts\activate.bat" (
            start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && call venv\Scripts\activate.bat && !PYTHON_CMD! -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_watchdog.log" 2>&1"
        ) else (
            start "WhatsApp-Scheduler-Backend" /min cmd /c "cd /d "%SCRIPT_DIR%\backend" && !PYTHON_CMD! -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_watchdog.log" 2>&1"
        )
        
        set "BACKEND_FAILURES=0"
        set "RESTART_NEEDED=1"
        echo.
    )
)

REM ============================================================================
REM  CHECK WHATSAPP SERVICE
REM ============================================================================
curl -s -o nul -w "" http://localhost:%WHATSAPP_PORT%/health --connect-timeout 5 >nul 2>&1
if %errorLevel% equ 0 (
    set "STATUS_LINE=!STATUS_LINE! WhatsApp:OK"
    set "WHATSAPP_FAILURES=0"
) else (
    set /a WHATSAPP_FAILURES+=1
    set "STATUS_LINE=!STATUS_LINE! WhatsApp:FAIL(!WHATSAPP_FAILURES!)"
    echo [%date% %time%] WhatsApp health check failed (!WHATSAPP_FAILURES!) >> "%WATCHDOG_LOG%"
    
    if !WHATSAPP_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        echo.
        echo    [WATCHDOG] Restarting WhatsApp Service...
        echo [%date% %time%] Restarting WhatsApp Service >> "%WATCHDOG_LOG%"
        
        for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%WHATSAPP_PORT% " ^| findstr "LISTENING"') do (
            taskkill /F /PID %%a >nul 2>&1
        )
        timeout /t 2 /nobreak >nul
        
        start "WhatsApp-Scheduler-WA" /min cmd /c "cd /d "%SCRIPT_DIR%\whatsapp-service" && node index.js >> "%SCRIPT_DIR%\logs\whatsapp\service_watchdog.log" 2>&1"
        
        set "WHATSAPP_FAILURES=0"
        set "RESTART_NEEDED=1"
        echo.
    )
)

REM ============================================================================
REM  CHECK FRONTEND
REM ============================================================================
curl -s -o nul -w "" http://localhost:%FRONTEND_PORT% --connect-timeout 5 >nul 2>&1
if %errorLevel% equ 0 (
    set "STATUS_LINE=!STATUS_LINE! Frontend:OK"
    set "FRONTEND_FAILURES=0"
) else (
    set /a FRONTEND_FAILURES+=1
    set "STATUS_LINE=!STATUS_LINE! Frontend:FAIL(!FRONTEND_FAILURES!)"
    echo [%date% %time%] Frontend health check failed (!FRONTEND_FAILURES!) >> "%WATCHDOG_LOG%"
    
    if !FRONTEND_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        echo.
        echo    [WATCHDOG] Restarting Frontend...
        echo [%date% %time%] Restarting Frontend >> "%WATCHDOG_LOG%"
        
        for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%FRONTEND_PORT% " ^| findstr "LISTENING"') do (
            taskkill /F /PID %%a >nul 2>&1
        )
        timeout /t 2 /nobreak >nul
        
        start "WhatsApp-Scheduler-Frontend" /min cmd /c "cd /d "%SCRIPT_DIR%\frontend" && set BROWSER=none && npm start >> "%SCRIPT_DIR%\logs\frontend\react_watchdog.log" 2>&1"
        
        set "FRONTEND_FAILURES=0"
        set "RESTART_NEEDED=1"
        echo.
    )
)

REM ============================================================================
REM  DISPLAY STATUS
REM ============================================================================
if "%RESTART_NEEDED%"=="0" (
    echo !STATUS_LINE!
)

timeout /t %CHECK_INTERVAL% /nobreak >nul

goto :watchdog_loop
