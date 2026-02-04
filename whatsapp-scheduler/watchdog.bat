@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Watchdog Service for Windows 10/11
REM  Version: 2.0 | Self-Healing | Auto-Recovery | Resource Monitor
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Watchdog
color 0D
mode con: cols=100 lines=40

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs\system"
set "WATCHDOG_LOG=%LOG_DIR%\watchdog.log"

set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"

set "CHECK_INTERVAL=30"
set "MAX_CONSECUTIVE_FAILURES=3"
set "MEMORY_WARNING_MB=200"
set "CPU_WARNING_PERCENT=95"

REM Failure counters
set "FRONTEND_FAILURES=0"
set "BACKEND_FAILURES=0"
set "WHATSAPP_FAILURES=0"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :LOG "============================================================================"
call :LOG "Watchdog Service Started"
call :LOG "Check interval: %CHECK_INTERVAL% seconds"
call :LOG "============================================================================"

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
echo    Press CTRL+C to stop monitoring
echo.
echo   ---------------------------------------------------------------------------
echo.

REM ============================================================================
REM  WATCHDOG LOOP
REM ============================================================================
:watchdog_loop

REM Get current time
for /f "tokens=1-4 delims=:." %%a in ("%time%") do (
    set "CURRENT_TIME=%%a:%%b:%%c"
)
set "CURRENT_TIME=%CURRENT_TIME: =0%"

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
    call :LOG "Backend health check failed (failure #!BACKEND_FAILURES!)"
    
    if !BACKEND_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        call :RESTART_BACKEND
        set "BACKEND_FAILURES=0"
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
    call :LOG "WhatsApp health check failed (failure #!WHATSAPP_FAILURES!)"
    
    if !WHATSAPP_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        call :RESTART_WHATSAPP
        set "WHATSAPP_FAILURES=0"
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
    call :LOG "Frontend health check failed (failure #!FRONTEND_FAILURES!)"
    
    if !FRONTEND_FAILURES! GEQ %MAX_CONSECUTIVE_FAILURES% (
        call :RESTART_FRONTEND
        set "FRONTEND_FAILURES=0"
    )
)

REM ============================================================================
REM  CHECK SYSTEM RESOURCES
REM ============================================================================
for /f "skip=1" %%a in ('wmic os get freephysicalmemory 2^>nul') do (
    set "FREE_MEM=%%a"
    goto :mem_check_done
)
:mem_check_done
if defined FREE_MEM (
    set /a FREE_MEM_MB=!FREE_MEM!/1024
    if !FREE_MEM_MB! LSS %MEMORY_WARNING_MB% (
        set "STATUS_LINE=!STATUS_LINE! MEM:LOW(!FREE_MEM_MB!MB)"
        call :LOG "WARNING: Low memory - !FREE_MEM_MB! MB free"
    )
)

REM ============================================================================
REM  DISPLAY STATUS
REM ============================================================================
echo !STATUS_LINE!

REM Wait for next check
timeout /t %CHECK_INTERVAL% /nobreak >nul

goto :watchdog_loop

REM ============================================================================
REM  RESTART FUNCTIONS
REM ============================================================================

:RESTART_BACKEND
echo.
echo    [WATCHDOG] Restarting Backend API...
call :LOG "Restarting Backend API"

REM Kill existing process
for /f "tokens=5" %%a in ('netstat -ano ^| find ":%BACKEND_PORT% " ^| find "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)

REM Wait for port to be released
timeout /t 2 /nobreak >nul

REM Start backend
cd /d "%SCRIPT_DIR%\backend"
if exist "venv\Scripts\activate.bat" (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "call venv\Scripts\activate.bat && python -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_watchdog.log" 2>&1"
) else (
    start "WhatsApp-Scheduler-Backend" /min cmd /c "python -m uvicorn server:app --host 0.0.0.0 --port %BACKEND_PORT% >> "%SCRIPT_DIR%\logs\backend\api_watchdog.log" 2>&1"
)
cd /d "%SCRIPT_DIR%"

call :LOG "Backend restart command issued"
echo    [WATCHDOG] Backend restart initiated
echo.
goto :eof

:RESTART_WHATSAPP
echo.
echo    [WATCHDOG] Restarting WhatsApp Service...
call :LOG "Restarting WhatsApp Service"

REM Kill existing process
for /f "tokens=5" %%a in ('netstat -ano ^| find ":%WHATSAPP_PORT% " ^| find "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)

timeout /t 2 /nobreak >nul

cd /d "%SCRIPT_DIR%\whatsapp-service"
start "WhatsApp-Scheduler-WA" /min cmd /c "node index.js >> "%SCRIPT_DIR%\logs\whatsapp\service_watchdog.log" 2>&1"
cd /d "%SCRIPT_DIR%"

call :LOG "WhatsApp service restart command issued"
echo    [WATCHDOG] WhatsApp service restart initiated
echo.
goto :eof

:RESTART_FRONTEND
echo.
echo    [WATCHDOG] Restarting Frontend...
call :LOG "Restarting Frontend"

REM Kill existing process
for /f "tokens=5" %%a in ('netstat -ano ^| find ":%FRONTEND_PORT% " ^| find "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)

timeout /t 2 /nobreak >nul

cd /d "%SCRIPT_DIR%\frontend"
start "WhatsApp-Scheduler-Frontend" /min cmd /c "set BROWSER=none&& npm start >> "%SCRIPT_DIR%\logs\frontend\react_watchdog.log" 2>&1"
cd /d "%SCRIPT_DIR%"

call :LOG "Frontend restart command issued"
echo    [WATCHDOG] Frontend restart initiated
echo.
goto :eof

:LOG
echo [%date% %time%] %~1 >> "%WATCHDOG_LOG%" 2>nul
goto :eof
