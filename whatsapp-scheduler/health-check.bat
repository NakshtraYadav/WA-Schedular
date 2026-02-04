@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Health Check Script for Windows 10/11
REM  Version: 2.1 | Fixed path handling
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Health Check
color 0F
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "LOG_DIR=%SCRIPT_DIR%\logs\system"

set "FRONTEND_PORT=3000"
set "BACKEND_PORT=8001"
set "WHATSAPP_PORT=3001"
set "MONGO_PORT=27017"

REM ============================================================================
REM  DISPLAY
REM ============================================================================
cls
echo.
echo   ===========================================================================
echo              WhatsApp Scheduler - System Health Check
echo   ===========================================================================
echo.
echo    Running diagnostics...                               %date% %time%
echo.
echo   ---------------------------------------------------------------------------
echo    SERVICE STATUS
echo   ---------------------------------------------------------------------------
echo.

set "ISSUES_FOUND=0"

REM ============================================================================
REM  CHECK MONGODB
REM ============================================================================
echo    MongoDB (Port %MONGO_PORT%):
netstat -an 2>nul | findstr ":%MONGO_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] MongoDB is running
) else (
    sc query MongoDB 2>nul | find "RUNNING" >nul
    if !errorLevel! equ 0 (
        echo          [OK] MongoDB service running
    ) else (
        echo          [--] MongoDB not running locally
    )
)
echo.

REM ============================================================================
REM  CHECK WHATSAPP SERVICE
REM ============================================================================
echo    WhatsApp Service (Port %WHATSAPP_PORT%):
netstat -an 2>nul | findstr ":%WHATSAPP_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] Health endpoint responding
    ) else (
        echo          [!!] Health endpoint not responding
        set /a ISSUES_FOUND+=1
    )
) else (
    echo          [!!] NOT RUNNING
    set /a ISSUES_FOUND+=1
)
echo.

REM ============================================================================
REM  CHECK BACKEND
REM ============================================================================
echo    Backend API (Port %BACKEND_PORT%):
netstat -an 2>nul | findstr ":%BACKEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] API root responding
    ) else (
        echo          [!!] API not responding
        set /a ISSUES_FOUND+=1
    )
) else (
    echo          [!!] NOT RUNNING
    set /a ISSUES_FOUND+=1
)
echo.

REM ============================================================================
REM  CHECK FRONTEND
REM ============================================================================
echo    Frontend (Port %FRONTEND_PORT%):
netstat -an 2>nul | findstr ":%FRONTEND_PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] Frontend responding
    ) else (
        echo          [!] Frontend may be compiling
    )
) else (
    echo          [!!] NOT RUNNING
    set /a ISSUES_FOUND+=1
)
echo.

REM ============================================================================
REM  SUMMARY
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    HEALTH CHECK SUMMARY
echo   ---------------------------------------------------------------------------
echo.

if %ISSUES_FOUND% equ 0 (
    color 0A
    echo    [OK] All systems operational - No issues found
    echo.
) else (
    color 0C
    echo    [!!] Found %ISSUES_FOUND% issue(s) requiring attention
    echo.
    echo    Recommended: Run restart.bat to restart all services
    echo.
)

echo   ===========================================================================
echo.

REM ============================================================================
REM  AUTO-REPAIR OPTION
REM ============================================================================
if %ISSUES_FOUND% GTR 0 (
    echo    Would you like to attempt auto-repair? (Y/N)
    set /p AUTO_REPAIR="    Choice: "
    
    if /i "!AUTO_REPAIR!"=="Y" (
        echo.
        echo    Attempting auto-repair...
        echo.
        call "%SCRIPT_DIR%\restart.bat"
    )
)

pause
exit /b %ISSUES_FOUND%
