@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Remove Windows Task Scheduler Entry
REM  Run as Administrator
REM ============================================================================

echo.
echo   ===========================================================================
echo        Removing WhatsApp Scheduler Auto-Start Task
echo   ===========================================================================
echo.

REM Check admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo    [!!] This script requires Administrator privileges.
    echo.
    echo    Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

REM Delete task
echo    [..] Removing scheduled task...

schtasks /Delete /TN "WhatsAppScheduler\AutoStart" /F >nul 2>&1
schtasks /Delete /TN "WhatsAppScheduler" /F >nul 2>&1

echo    [OK] Auto-start task removed.
echo.
echo    The WhatsApp Scheduler will no longer start automatically.
echo.
echo    To re-enable auto-start, run: install-task.bat
echo.

pause
