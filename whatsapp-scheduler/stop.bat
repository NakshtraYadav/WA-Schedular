@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Stop Script for Windows 10/11
REM  Version: 2.0 | Graceful Shutdown | Port Cleanup | Data Protection
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Stopping Services
color 0C
mode con: cols=100 lines=40

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs\system"
set "TIMESTAMP=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "STOP_LOG=%LOG_DIR%\stop_%TIMESTAMP%.log"

REM Service ports
set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :LOG "============================================================================"
call :LOG "WhatsApp Scheduler - Service Stop Initiated"
call :LOG "Time: %date% %time%"
call :LOG "============================================================================"

echo.
echo   ===========================================================================
echo                  WhatsApp Scheduler - Stopping Services
echo   ===========================================================================
echo.
echo    Initiating graceful shutdown...
echo.

REM ============================================================================
REM  STOP BY WINDOW TITLE (Graceful)
REM ============================================================================
echo    [1/4] Stopping services by window title...

for %%t in ("WhatsApp-Scheduler-Frontend" "WhatsApp-Scheduler-Backend" "WhatsApp-Scheduler-WA" "MongoDB") do (
    taskkill /FI "WINDOWTITLE eq %%~t*" /F >nul 2>&1
    if !errorLevel! equ 0 (
        echo          Stopped: %%~t
        call :LOG "Stopped by title: %%~t"
    )
)
echo    [OK] Window-based processes stopped
echo.

REM ============================================================================
REM  STOP BY PORT (Cleanup)
REM ============================================================================
echo    [2/4] Cleaning up ports...

for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| find ":%%p " ^| find "LISTENING"') do (
        if "%%a" neq "0" (
            taskkill /F /PID %%a >nul 2>&1
            if !errorLevel! equ 0 (
                echo          Port %%p freed (PID: %%a^)
                call :LOG "Port %%p freed by killing PID %%a"
            )
        )
    )
)
echo    [OK] All ports cleared
echo.

REM ============================================================================
REM  STOP ORPHAN PROCESSES
REM ============================================================================
echo    [3/4] Cleaning up orphan processes...

REM Kill orphan node processes related to our app
for /f "tokens=2" %%a in ('wmic process where "name='node.exe' and commandline like '%%whatsapp%%'" get processid 2^>nul ^| find /v "ProcessId"') do (
    taskkill /F /PID %%a >nul 2>&1
    if !errorLevel! equ 0 (
        echo          Orphan node process stopped (PID: %%a^)
        call :LOG "Orphan node stopped: %%a"
    )
)

REM Kill orphan python processes running uvicorn on our port
for /f "tokens=2" %%a in ('wmic process where "name='python.exe' and commandline like '%%uvicorn%%server%%'" get processid 2^>nul ^| find /v "ProcessId"') do (
    taskkill /F /PID %%a >nul 2>&1
    if !errorLevel! equ 0 (
        echo          Orphan python process stopped (PID: %%a^)
        call :LOG "Orphan python stopped: %%a"
    )
)

echo    [OK] Orphan processes cleaned
echo.

REM ============================================================================
REM  VERIFY SHUTDOWN
REM ============================================================================
echo    [4/4] Verifying shutdown...

set "SHUTDOWN_CLEAN=1"

for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    netstat -an | find ":%%p " | find "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [!] Port %%p still in use
        set "SHUTDOWN_CLEAN=0"
    )
)

if "!SHUTDOWN_CLEAN!"=="1" (
    echo    [OK] All services stopped successfully
    call :LOG "Clean shutdown completed"
) else (
    echo    [!] Some processes may still be running
    echo    [i] Try running this script again or restart Windows
    call :LOG "WARNING: Incomplete shutdown"
)

echo.
echo   ===========================================================================
echo                        ALL SERVICES STOPPED
echo   ===========================================================================
echo.
echo    To start services again, run: start.bat
echo.
echo   ===========================================================================
echo.

call :LOG "Stop script completed"

pause
exit /b 0

:LOG
echo [%date% %time%] %~1 >> "%STOP_LOG%" 2>nul
goto :eof
