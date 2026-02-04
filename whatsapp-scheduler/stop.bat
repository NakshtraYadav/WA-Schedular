@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Stop Script for Windows 10/11
REM  Version: 2.1 | Fixed path handling for spaces
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

for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,8%_%dt:~8,6%"
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
REM  STOP ORPHAN PROCESSES
REM ============================================================================
echo    [3/4] Cleaning up orphan processes...

REM Kill orphan node processes (whatsapp service and any npm)
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='node.exe' and commandline like '%%whatsapp%%'" get processid 2^>nul') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1
        echo          Orphan node stopped (PID: %%a^)
    )
)

REM Kill any node processes related to our frontend
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='node.exe' and commandline like '%%react-scripts%%'" get processid 2^>nul') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1
        echo          Frontend node stopped (PID: %%a^)
    )
)

REM Kill orphan python uvicorn processes
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='python.exe' and commandline like '%%uvicorn%%server%%'" get processid 2^>nul') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1
        echo          Orphan python stopped (PID: %%a^)
    )
)

REM Also check pythonw.exe (windowless python)
for /f "skip=1 tokens=2" %%a in ('wmic process where "name='pythonw.exe' and commandline like '%%uvicorn%%'" get processid 2^>nul') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1
        echo          Orphan pythonw stopped (PID: %%a^)
    )
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
echo    To start services again, run: start.bat
echo.
echo   ===========================================================================
echo.

echo [%date% %time%] Stop script completed >> "%STOP_LOG%"

pause
exit /b 0
