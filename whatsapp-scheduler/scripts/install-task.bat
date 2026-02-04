@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Install Windows Task Scheduler Entry
REM  Run as Administrator
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
set "PARENT_DIR=%PARENT_DIR:~0,-1%"

echo.
echo   ===========================================================================
echo        Installing WhatsApp Scheduler Auto-Start Task
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

REM Create task
echo    [..] Creating scheduled task...

schtasks /Create /TN "WhatsAppScheduler\AutoStart" /TR "\"%PARENT_DIR%\start.bat\"" /SC ONLOGON /DELAY 0001:00 /RL HIGHEST /F >nul 2>&1

if %errorLevel% equ 0 (
    echo    [OK] Task created successfully!
    echo.
    echo    The WhatsApp Scheduler will now start automatically when you log in.
    echo.
    echo    To disable auto-start, run: uninstall-task.bat
    echo.
) else (
    echo    [!!] Failed to create task.
    echo    Error code: %errorLevel%
    echo.
)

pause
