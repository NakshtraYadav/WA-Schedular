@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Health Check Script for Windows 10/11
REM  Version: 2.0 | Service Diagnostics | Auto-Repair
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Health Check
color 0F
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
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
netstat -an | find ":%MONGO_PORT% " | find "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] MongoDB is running
) else (
    sc query MongoDB 2>nul | find "RUNNING" >nul
    if !errorLevel! equ 0 (
        echo          [OK] MongoDB service running
    ) else (
        echo          [--] MongoDB not running locally (Atlas?^)
    )
)
echo.

REM ============================================================================
REM  CHECK WHATSAPP SERVICE
REM ============================================================================
echo    WhatsApp Service (Port %WHATSAPP_PORT%):
netstat -an | find ":%WHATSAPP_PORT% " | find "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    REM Check health endpoint
    curl -s http://localhost:%WHATSAPP_PORT%/health >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] Health endpoint responding
        
        REM Get detailed status
        for /f "delims=" %%a in ('curl -s http://localhost:%WHATSAPP_PORT%/status 2^>nul') do (
            echo          [i] Status: %%a
        )
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
netstat -an | find ":%BACKEND_PORT% " | find "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    REM Check API root
    curl -s http://localhost:%BACKEND_PORT%/api/ >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] API root responding
        
        REM Check dashboard stats endpoint
        curl -s http://localhost:%BACKEND_PORT%/api/dashboard/stats >nul 2>&1
        if !errorLevel! equ 0 (
            echo          [OK] Dashboard API working
        ) else (
            echo          [!] Dashboard API issue (DB connection?^)
        )
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
netstat -an | find ":%FRONTEND_PORT% " | find "LISTENING" >nul 2>&1
if %errorLevel% equ 0 (
    echo          [OK] Service listening on port
    
    curl -s http://localhost:%FRONTEND_PORT% >nul 2>&1
    if !errorLevel! equ 0 (
        echo          [OK] Frontend responding
    ) else (
        echo          [!] Frontend slow or compiling
    )
) else (
    echo          [!!] NOT RUNNING
    set /a ISSUES_FOUND+=1
)
echo.

REM ============================================================================
REM  SYSTEM RESOURCES
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    SYSTEM RESOURCES
echo   ---------------------------------------------------------------------------
echo.

REM Memory usage
for /f "skip=1" %%a in ('wmic os get freephysicalmemory 2^>nul') do (
    set "FREE_MEM=%%a"
    goto :mem_done
)
:mem_done
if defined FREE_MEM (
    set /a FREE_MEM_MB=!FREE_MEM!/1024
    echo    Free Memory:       !FREE_MEM_MB! MB
    if !FREE_MEM_MB! LSS 500 (
        echo          [!!] LOW MEMORY WARNING
        set /a ISSUES_FOUND+=1
    )
)

REM CPU usage
for /f "skip=1" %%a in ('wmic cpu get loadpercentage 2^>nul') do (
    set "CPU_LOAD=%%a"
    goto :cpu_done
)
:cpu_done
if defined CPU_LOAD (
    echo    CPU Load:          !CPU_LOAD!%%
    if !CPU_LOAD! GTR 90 (
        echo          [!!] HIGH CPU WARNING
    )
)

REM Disk space
for /f "skip=1 tokens=1,2" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace^,Size 2^>nul') do (
    set "FREE_DISK=%%a"
    set "TOTAL_DISK=%%b"
    goto :disk_done
)
:disk_done
if defined FREE_DISK (
    set /a FREE_DISK_GB=!FREE_DISK:~0,-9!
    echo    Free Disk (C:):    !FREE_DISK_GB! GB
    if !FREE_DISK_GB! LSS 1 (
        echo          [!!] LOW DISK SPACE WARNING
        set /a ISSUES_FOUND+=1
    )
)
echo.

REM ============================================================================
REM  LOG FILE STATUS
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    LOG FILES
echo   ---------------------------------------------------------------------------
echo.

if exist "%SCRIPT_DIR%\logs\backend" (
    for /f %%a in ('dir /b "%SCRIPT_DIR%\logs\backend\*.log" 2^>nul ^| find /c /v ""') do (
        echo    Backend logs:      %%a files
    )
)
if exist "%SCRIPT_DIR%\logs\frontend" (
    for /f %%a in ('dir /b "%SCRIPT_DIR%\logs\frontend\*.log" 2^>nul ^| find /c /v ""') do (
        echo    Frontend logs:     %%a files
    )
)
if exist "%SCRIPT_DIR%\logs\whatsapp" (
    for /f %%a in ('dir /b "%SCRIPT_DIR%\logs\whatsapp\*.log" 2^>nul ^| find /c /v ""') do (
        echo    WhatsApp logs:     %%a files
    )
)
if exist "%SCRIPT_DIR%\logs\system" (
    for /f %%a in ('dir /b "%SCRIPT_DIR%\logs\system\*.log" 2^>nul ^| find /c /v ""') do (
        echo    System logs:       %%a files
    )
)
echo.

REM ============================================================================
REM  SUMMARY
REM ============================================================================
echo   ---------------------------------------------------------------------------
echo    HEALTH CHECK SUMMARY
echo   ---------------------------------------------------------------------------
echo.

if !ISSUES_FOUND! equ 0 (
    color 0A
    echo    [OK] All systems operational - No issues found
    echo.
) else (
    color 0C
    echo    [!!] Found !ISSUES_FOUND! issue(s^) requiring attention
    echo.
    echo    Recommended actions:
    echo    1. Run restart.bat to restart all services
    echo    2. Check log files in logs\ folder
    echo    3. Run setup.bat if dependencies are missing
    echo.
)

echo   ===========================================================================
echo.

REM ============================================================================
REM  AUTO-REPAIR OPTION
REM ============================================================================
if !ISSUES_FOUND! GTR 0 (
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
exit /b !ISSUES_FOUND!
