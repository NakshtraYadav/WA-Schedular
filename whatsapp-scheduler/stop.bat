@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Stop Script for Windows 10/11
REM  Version: 3.0 | Uses PowerShell instead of deprecated WMIC
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Stopping Services
color 0C
mode con: cols=100 lines=40

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs\system"

REM Get timestamp using PowerShell (WMIC is deprecated in Windows 11)
for /f %%a in ('powershell -Command "Get-Date -Format \"yyyyMMdd_HHmmss\""') do set "TIMESTAMP=%%a"
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

echo [%date% %time%] Service Stop Initiated > "%STOP_LOG%"

echo.
echo   ===========================================================================
echo                  WhatsApp Scheduler - Stopping Services
echo   ===========================================================================
echo.
echo    Initiating graceful shutdown...
echo.

REM ============================================================================
REM  STOP BY WINDOW TITLE
REM ============================================================================
echo    [1/4] Stopping services by window title...

taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-Frontend*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-Backend*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq WhatsApp-Scheduler-WA*" /F >nul 2>&1

echo    [OK] Window-based processes stopped
echo [%date% %time%] Window processes stopped >> "%STOP_LOG%"
echo.

REM ============================================================================
REM  STOP BY PORT
REM ============================================================================
echo    [2/4] Cleaning up ports...

for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        if "%%a" neq "0" (
            taskkill /F /PID %%a >nul 2>&1
            echo          Port %%p freed (PID: %%a^)
            echo [%date% %time%] Port %%p freed - PID %%a >> "%STOP_LOG%"
        )
    )
)
echo    [OK] All ports cleared
echo.

REM ============================================================================
REM  STOP ORPHAN PROCESSES (Using PowerShell instead of WMIC)
REM ============================================================================
echo    [3/4] Cleaning up orphan processes...

REM Kill orphan node processes (whatsapp service)
for /f %%a in ('powershell -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*whatsapp*'} | Select-Object -ExpandProperty Id"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo          WhatsApp node stopped (PID: %%a^)
)

REM Kill any node processes related to frontend (react-scripts)
for /f %%a in ('powershell -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*react-scripts*'} | Select-Object -ExpandProperty Id"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo          Frontend node stopped (PID: %%a^)
)

REM Kill orphan python uvicorn processes
for /f %%a in ('powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*uvicorn*server*'} | Select-Object -ExpandProperty Id"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo          Backend python stopped (PID: %%a^)
)

REM Also check pythonw.exe (windowless python)
for /f %%a in ('powershell -Command "Get-Process pythonw -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*uvicorn*'} | Select-Object -ExpandProperty Id"') do (
    taskkill /F /PID %%a >nul 2>&1
    echo          Backend pythonw stopped (PID: %%a^)
)

echo    [OK] Orphan processes cleaned
echo [%date% %time%] Orphan processes cleaned >> "%STOP_LOG%"
echo.

REM ============================================================================
REM  VERIFY SHUTDOWN
REM ============================================================================
echo    [4/4] Verifying shutdown...

set "SHUTDOWN_CLEAN=1"

for %%p in (%FRONTEND_PORT% %BACKEND_PORT% %WHATSAPP_PORT%) do (
    netstat -an 2>nul | findstr ":%%p " | findstr "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [!] Port %%p still in use
        set "SHUTDOWN_CLEAN=0"
    )
)

if "%SHUTDOWN_CLEAN%"=="1" (
    echo    [OK] All services stopped successfully
    echo [%date% %time%] Clean shutdown completed >> "%STOP_LOG%"
) else (
    echo    [!] Some processes may still be running
    echo    [i] Try running this script again
    echo [%date% %time%] WARNING: Incomplete shutdown >> "%STOP_LOG%"
)

echo.
echo   ===========================================================================
echo                        ALL SERVICES STOPPED
echo   ===========================================================================
echo.
echo    To start services again, run: start.bat or launch.bat
echo.
echo   ===========================================================================
echo.

echo [%date% %time%] Stop script completed >> "%STOP_LOG%"

pause
exit /b 0
