@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Restart Script for Windows 10/11
REM  Version: 2.0 | Clean Restart | Service Recovery
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Restarting
color 0E

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo.
echo   ===========================================================================
echo                  WhatsApp Scheduler - Service Restart
echo   ===========================================================================
echo.
echo    Stopping all services...
echo.

REM Call stop script (silent mode)
call "%SCRIPT_DIR%\stop.bat" >nul 2>&1

REM Wait for ports to be fully released
echo    Waiting for ports to be released...
timeout /t 5 /nobreak >nul

REM Verify ports are free
set "PORTS_FREE=1"
for %%p in (3000 8001 3001) do (
    netstat -an | find ":%%p " | find "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo    [!] Port %%p still in use, forcing cleanup...
        for /f "tokens=5" %%a in ('netstat -ano ^| find ":%%p " ^| find "LISTENING"') do (
            taskkill /F /PID %%a >nul 2>&1
        )
        set "PORTS_FREE=0"
    )
)

if "!PORTS_FREE!"=="0" (
    echo    Waiting additional 3 seconds...
    timeout /t 3 /nobreak >nul
)

echo.
echo    Starting all services...
echo.

REM Start services
call "%SCRIPT_DIR%\start.bat"
