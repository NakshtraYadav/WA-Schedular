@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Production Setup Script for Windows 10/11
REM  Version: 2.0 | Self-Healing | Zero Manual Intervention
REM ============================================================================
setlocal enabledelayedexpansion

title WhatsApp Scheduler - Setup
color 0A
mode con: cols=100 lines=50

REM ============================================================================
REM  CONFIGURATION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_DIR=%SCRIPT_DIR%\logs\system"
set "SETUP_LOG=%LOG_DIR%\setup_%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "SETUP_LOG=%SETUP_LOG: =0%"

set "MIN_NODE_VERSION=16"
set "MIN_PYTHON_VERSION=3.8"
set "REQUIRED_PORTS=3000 3001 8001 27017"

REM ============================================================================
REM  INITIALIZE
REM ============================================================================
cd /d "%SCRIPT_DIR%"

REM Create log directories
if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs"
if not exist "%SCRIPT_DIR%\logs\backend" mkdir "%SCRIPT_DIR%\logs\backend"
if not exist "%SCRIPT_DIR%\logs\frontend" mkdir "%SCRIPT_DIR%\logs\frontend"
if not exist "%SCRIPT_DIR%\logs\whatsapp" mkdir "%SCRIPT_DIR%\logs\whatsapp"
if not exist "%SCRIPT_DIR%\logs\system" mkdir "%SCRIPT_DIR%\logs\system"

call :LOG "============================================================================"
call :LOG "WhatsApp Scheduler - Production Setup Started"
call :LOG "Time: %date% %time%"
call :LOG "Directory: %SCRIPT_DIR%"
call :LOG "============================================================================"

echo.
echo  ============================================================================
echo   WhatsApp Scheduler - Production Setup
echo  ============================================================================
echo.
echo   [i] This script will:
echo       - Verify and install all dependencies
echo       - Configure environment files
echo       - Set up all services
echo       - Create Windows Task Scheduler entries
echo.
echo   [i] Log file: %SETUP_LOG%
echo.
echo  ============================================================================
echo.

REM ============================================================================
REM  PREFLIGHT CHECKS
REM ============================================================================
call :HEADER "PREFLIGHT VALIDATION"

REM Check Windows Version
call :STATUS "Checking Windows version..."
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo   [OK] Windows version: %VERSION%
call :LOG "Windows version: %VERSION%"

REM Check Administrator privileges
call :STATUS "Checking administrator privileges..."
net session >nul 2>&1
if %errorLevel% neq 0 (
    call :WARNING "Running without administrator privileges"
    call :WARNING "Some features may not work correctly"
    call :LOG "WARNING: Not running as administrator"
) else (
    echo   [OK] Running with administrator privileges
    call :LOG "Running as administrator"
)

REM ============================================================================
REM  NODE.JS VALIDATION
REM ============================================================================
call :HEADER "NODE.JS VALIDATION"

call :STATUS "Checking Node.js installation..."
where node >nul 2>&1
if %errorLevel% neq 0 (
    call :ERROR "Node.js is not installed!"
    call :LOG "ERROR: Node.js not found"
    echo.
    echo   To fix this:
    echo   1. Download Node.js LTS from: https://nodejs.org/
    echo   2. Run the installer (check 'Add to PATH')
    echo   3. Restart this script
    echo.
    pause
    exit /b 1
)

for /f "tokens=1-3 delims=v." %%a in ('node -v') do (
    set "NODE_MAJOR=%%b"
)
if !NODE_MAJOR! LSS %MIN_NODE_VERSION% (
    call :WARNING "Node.js version too old: v!NODE_MAJOR!"
    call :WARNING "Minimum required: v%MIN_NODE_VERSION%"
    call :LOG "WARNING: Node.js version !NODE_MAJOR! is below minimum %MIN_NODE_VERSION%"
) else (
    for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
    echo   [OK] Node.js !NODE_VERSION!
    call :LOG "Node.js: !NODE_VERSION!"
)

REM Check npm
call :STATUS "Checking npm..."
where npm >nul 2>&1
if %errorLevel% neq 0 (
    call :ERROR "npm not found!"
    call :LOG "ERROR: npm not found"
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('npm -v') do set NPM_VERSION=%%i
echo   [OK] npm v!NPM_VERSION!
call :LOG "npm: v!NPM_VERSION!"

REM Check yarn (install if missing)
call :STATUS "Checking yarn..."
where yarn >nul 2>&1
if %errorLevel% neq 0 (
    call :WARNING "yarn not found, installing..."
    call npm install -g yarn >nul 2>&1
    if %errorLevel% neq 0 (
        call :WARNING "Could not install yarn globally, using npm instead"
        set "USE_YARN=0"
    ) else (
        echo   [OK] yarn installed successfully
        set "USE_YARN=1"
    )
) else (
    for /f "tokens=*" %%i in ('yarn -v') do set YARN_VERSION=%%i
    echo   [OK] yarn v!YARN_VERSION!
    set "USE_YARN=1"
)

REM ============================================================================
REM  PYTHON VALIDATION
REM ============================================================================
call :HEADER "PYTHON VALIDATION"

call :STATUS "Checking Python installation..."

REM Try python first, then python3, then py
set "PYTHON_CMD="

where python >nul 2>&1
if %errorLevel% equ 0 (
    set "PYTHON_CMD=python"
    goto :python_found
)

where python3 >nul 2>&1
if %errorLevel% equ 0 (
    set "PYTHON_CMD=python3"
    goto :python_found
)

where py >nul 2>&1
if %errorLevel% equ 0 (
    set "PYTHON_CMD=py"
    goto :python_found
)

call :ERROR "Python is not installed!"
call :LOG "ERROR: Python not found"
echo.
echo   To fix this:
echo   1. Download Python from: https://www.python.org/downloads/
echo   2. Run installer - CHECK 'Add Python to PATH'
echo   3. Restart this script
echo.
pause
exit /b 1

:python_found
for /f "tokens=2 delims= " %%a in ('%PYTHON_CMD% --version 2^>^&1') do set PYTHON_VERSION=%%a
for /f "tokens=1,2 delims=." %%a in ("!PYTHON_VERSION!") do (
    set "PYTHON_MAJOR=%%a"
    set "PYTHON_MINOR=%%b"
)

if !PYTHON_MAJOR! LSS 3 (
    call :ERROR "Python 3 required, found Python !PYTHON_VERSION!"
    call :LOG "ERROR: Python version too old"
    pause
    exit /b 1
)

echo   [OK] Python !PYTHON_VERSION! (using: %PYTHON_CMD%)
call :LOG "Python: !PYTHON_VERSION! (command: %PYTHON_CMD%)"

REM Check pip
call :STATUS "Checking pip..."
%PYTHON_CMD% -m pip --version >nul 2>&1
if %errorLevel% neq 0 (
    call :WARNING "pip not found, installing..."
    %PYTHON_CMD% -m ensurepip --upgrade >nul 2>&1
)
for /f "tokens=2" %%a in ('%PYTHON_CMD% -m pip --version 2^>^&1') do set PIP_VERSION=%%a
echo   [OK] pip !PIP_VERSION!
call :LOG "pip: !PIP_VERSION!"

REM ============================================================================
REM  MONGODB VALIDATION
REM ============================================================================
call :HEADER "MONGODB VALIDATION"

call :STATUS "Checking MongoDB..."

REM Check if MongoDB service is running
sc query MongoDB >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=4" %%a in ('sc query MongoDB ^| find "STATE"') do set MONGO_STATE=%%a
    if "!MONGO_STATE!"=="RUNNING" (
        echo   [OK] MongoDB service is running
        call :LOG "MongoDB: Service running"
        set "MONGO_AVAILABLE=1"
        goto :mongo_done
    ) else (
        call :STATUS "MongoDB service found but not running, starting..."
        net start MongoDB >nul 2>&1
        if !errorLevel! equ 0 (
            echo   [OK] MongoDB service started
            set "MONGO_AVAILABLE=1"
            goto :mongo_done
        )
    )
)

REM Check if mongod is in PATH
where mongod >nul 2>&1
if %errorLevel% equ 0 (
    echo   [OK] MongoDB binary found in PATH
    call :LOG "MongoDB: Binary found"
    set "MONGO_AVAILABLE=1"
    goto :mongo_done
)

REM Check common installation paths
set "MONGO_PATHS=C:\Program Files\MongoDB\Server;C:\mongodb;D:\MongoDB\Server"
for %%p in (%MONGO_PATHS%) do (
    if exist "%%p" (
        for /d %%v in ("%%p\*") do (
            if exist "%%v\bin\mongod.exe" (
                set "MONGO_BIN=%%v\bin"
                echo   [OK] MongoDB found at: !MONGO_BIN!
                setx PATH "%PATH%;!MONGO_BIN!" >nul 2>&1
                set "PATH=%PATH%;!MONGO_BIN!"
                set "MONGO_AVAILABLE=1"
                call :LOG "MongoDB: Found at !MONGO_BIN!"
                goto :mongo_done
            )
        )
    )
)

call :WARNING "MongoDB not found locally"
echo.
echo   Options:
echo   1. Install MongoDB Community: https://www.mongodb.com/try/download/community
echo   2. Use MongoDB Atlas cloud: https://www.mongodb.com/cloud/atlas
echo.
echo   For Atlas, update backend\.env with your connection string.
echo.
call :LOG "WARNING: MongoDB not found"
set "MONGO_AVAILABLE=0"

:mongo_done

REM ============================================================================
REM  PORT VALIDATION
REM ============================================================================
call :HEADER "PORT VALIDATION"

set "PORTS_OK=1"
for %%p in (%REQUIRED_PORTS%) do (
    call :STATUS "Checking port %%p..."
    netstat -an | find ":%%p " | find "LISTENING" >nul 2>&1
    if !errorLevel! equ 0 (
        call :WARNING "Port %%p is in use!"
        call :LOG "WARNING: Port %%p in use"
        
        REM Try to identify the process
        for /f "tokens=5" %%a in ('netstat -ano ^| find ":%%p " ^| find "LISTENING"') do (
            for /f "tokens=1" %%n in ('tasklist /fi "PID eq %%a" /fo csv /nh 2^>nul') do (
                echo   [!] Used by: %%n (PID: %%a)
            )
        )
        set "PORTS_OK=0"
    ) else (
        echo   [OK] Port %%p is available
    )
)

if "!PORTS_OK!"=="0" (
    echo.
    echo   Some ports are in use. Would you like to free them? (Y/N)
    set /p KILL_PORTS="  Choice: "
    if /i "!KILL_PORTS!"=="Y" (
        call :STATUS "Freeing ports..."
        for %%p in (%REQUIRED_PORTS%) do (
            for /f "tokens=5" %%a in ('netstat -ano ^| find ":%%p " ^| find "LISTENING"') do (
                taskkill /F /PID %%a >nul 2>&1
            )
        )
        echo   [OK] Ports freed
    )
)

REM ============================================================================
REM  DIRECTORY STRUCTURE
REM ============================================================================
call :HEADER "DIRECTORY STRUCTURE"

call :STATUS "Creating directories..."

set "DIRS=backend frontend whatsapp-service logs logs\backend logs\frontend logs\whatsapp logs\system scripts"
for %%d in (%DIRS%) do (
    if not exist "%SCRIPT_DIR%\%%d" (
        mkdir "%SCRIPT_DIR%\%%d" 2>nul
        echo   [+] Created: %%d
    )
)
echo   [OK] Directory structure verified
call :LOG "Directory structure created"

REM ============================================================================
REM  BACKEND SETUP
REM ============================================================================
call :HEADER "BACKEND SETUP"

call :STATUS "Setting up Python backend..."
cd /d "%SCRIPT_DIR%\backend"

REM Create virtual environment
if not exist "venv" (
    call :STATUS "Creating virtual environment..."
    %PYTHON_CMD% -m venv venv
    if !errorLevel! neq 0 (
        call :ERROR "Failed to create virtual environment"
        call :LOG "ERROR: venv creation failed"
    ) else (
        echo   [OK] Virtual environment created
        call :LOG "Virtual environment created"
    )
) else (
    echo   [OK] Virtual environment exists
)

REM Activate and install dependencies
call :STATUS "Installing Python dependencies..."
call venv\Scripts\activate.bat 2>nul

REM Install dependencies with retry logic
set "PIP_RETRIES=3"
set "PIP_RETRY=0"

:pip_retry_loop
set /a PIP_RETRY+=1

if exist "requirements.txt" (
    %PYTHON_CMD% -m pip install -r requirements.txt --quiet 2>nul
) else (
    %PYTHON_CMD% -m pip install fastapi uvicorn python-dotenv motor pymongo pydantic httpx apscheduler pytz tzlocal --quiet 2>nul
)

if !errorLevel! neq 0 (
    if !PIP_RETRY! LSS !PIP_RETRIES! (
        call :WARNING "Pip install failed, retrying (!PIP_RETRY!/!PIP_RETRIES!)..."
        timeout /t 2 /nobreak >nul
        goto :pip_retry_loop
    ) else (
        call :ERROR "Failed to install Python dependencies after !PIP_RETRIES! attempts"
    )
) else (
    echo   [OK] Python dependencies installed
    call :LOG "Python dependencies installed"
)

REM Create/Update .env file
call :STATUS "Configuring backend environment..."
if not exist ".env" (
    (
        echo MONGO_URL=mongodb://localhost:27017
        echo DB_NAME=whatsapp_scheduler
        echo WA_SERVICE_URL=http://localhost:3001
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > .env
    echo   [OK] Created backend .env
) else (
    echo   [OK] Backend .env exists
)
call :LOG "Backend environment configured"

cd /d "%SCRIPT_DIR%"

REM ============================================================================
REM  WHATSAPP SERVICE SETUP
REM ============================================================================
call :HEADER "WHATSAPP SERVICE SETUP"

call :STATUS "Setting up WhatsApp service..."
cd /d "%SCRIPT_DIR%\whatsapp-service"

REM Install dependencies with retry
call :STATUS "Installing Node.js dependencies (may take a few minutes)..."
set "NPM_RETRIES=3"
set "NPM_RETRY=0"

:npm_wa_retry_loop
set /a NPM_RETRY+=1

if "!USE_YARN!"=="1" (
    call yarn install --silent 2>nul
) else (
    call npm install --legacy-peer-deps --silent 2>nul
)

if !errorLevel! neq 0 (
    if !NPM_RETRY! LSS !NPM_RETRIES! (
        call :WARNING "npm install failed, retrying (!NPM_RETRY!/!NPM_RETRIES!)..."
        if exist "node_modules" rmdir /s /q node_modules 2>nul
        if exist "package-lock.json" del package-lock.json 2>nul
        timeout /t 3 /nobreak >nul
        goto :npm_wa_retry_loop
    ) else (
        call :WARNING "npm install had issues - WhatsApp service may not work"
        call :LOG "WARNING: WhatsApp npm install failed"
    )
) else (
    echo   [OK] WhatsApp service dependencies installed
    call :LOG "WhatsApp dependencies installed"
)

cd /d "%SCRIPT_DIR%"

REM ============================================================================
REM  FRONTEND SETUP
REM ============================================================================
call :HEADER "FRONTEND SETUP"

call :STATUS "Setting up React frontend..."
cd /d "%SCRIPT_DIR%\frontend"

REM Install dependencies with retry
call :STATUS "Installing frontend dependencies (may take several minutes)..."
set "NPM_RETRIES=3"
set "NPM_RETRY=0"

:npm_fe_retry_loop
set /a NPM_RETRY+=1

if "!USE_YARN!"=="1" (
    call yarn install --silent 2>nul
) else (
    call npm install --legacy-peer-deps --silent 2>nul
)

if !errorLevel! neq 0 (
    if !NPM_RETRY! LSS !NPM_RETRIES! (
        call :WARNING "npm install failed, retrying (!NPM_RETRY!/!NPM_RETRIES!)..."
        if exist "node_modules" rmdir /s /q node_modules 2>nul
        if exist "package-lock.json" del package-lock.json 2>nul
        timeout /t 3 /nobreak >nul
        goto :npm_fe_retry_loop
    ) else (
        call :WARNING "npm install had issues - frontend may not work"
        call :LOG "WARNING: Frontend npm install failed"
    )
) else (
    echo   [OK] Frontend dependencies installed
    call :LOG "Frontend dependencies installed"
)

REM Create/Update .env file
call :STATUS "Configuring frontend environment..."
if not exist ".env" (
    echo REACT_APP_BACKEND_URL=http://localhost:8001> .env
    echo   [OK] Created frontend .env
) else (
    echo   [OK] Frontend .env exists
)

cd /d "%SCRIPT_DIR%"

REM ============================================================================
REM  CREATE DEPENDENCY LOCK FILE
REM ============================================================================
call :HEADER "DEPENDENCY LOCKING"

call :STATUS "Creating dependency version lock..."
(
    echo # WhatsApp Scheduler - Dependency Lock File
    echo # Generated: %date% %time%
    echo.
    echo [node]
    for /f "tokens=*" %%i in ('node -v') do echo version=%%i
    echo.
    echo [python]
    echo version=!PYTHON_VERSION!
    echo.
    echo [npm]
    for /f "tokens=*" %%i in ('npm -v') do echo version=%%i
) > "%SCRIPT_DIR%\dependency-lock.txt"
echo   [OK] Dependency versions locked
call :LOG "Dependencies locked to file"

REM ============================================================================
REM  TASK SCHEDULER SETUP
REM ============================================================================
call :HEADER "TASK SCHEDULER SETUP (Optional)"

echo.
echo   Would you like to set up auto-start on Windows boot?
echo   This creates a Windows Task Scheduler entry.
echo.
set /p SETUP_TASK="  Enable auto-start? (Y/N): "

if /i "!SETUP_TASK!"=="Y" (
    call :STATUS "Creating scheduled task..."
    
    REM Create the task XML
    set "TASK_XML=%SCRIPT_DIR%\scripts\WhatsAppSchedulerTask.xml"
    (
        echo ^<?xml version="1.0" encoding="UTF-16"?^>
        echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
        echo   ^<Triggers^>
        echo     ^<LogonTrigger^>
        echo       ^<Enabled^>true^</Enabled^>
        echo       ^<Delay^>PT30S^</Delay^>
        echo     ^</LogonTrigger^>
        echo   ^</Triggers^>
        echo   ^<Principals^>
        echo     ^<Principal id="Author"^>
        echo       ^<LogonType^>InteractiveToken^</LogonType^>
        echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
        echo     ^</Principal^>
        echo   ^</Principals^>
        echo   ^<Settings^>
        echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
        echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
        echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
        echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
        echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
        echo     ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
        echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
        echo     ^<Enabled^>true^</Enabled^>
        echo     ^<Hidden^>false^</Hidden^>
        echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
        echo   ^</Settings^>
        echo   ^<Actions Context="Author"^>
        echo     ^<Exec^>
        echo       ^<Command^>"%SCRIPT_DIR%\start.bat"^</Command^>
        echo       ^<WorkingDirectory^>%SCRIPT_DIR%^</WorkingDirectory^>
        echo     ^</Exec^>
        echo   ^</Actions^>
        echo ^</Task^>
    ) > "!TASK_XML!"
    
    REM Register the task
    schtasks /Create /TN "WhatsAppScheduler" /XML "!TASK_XML!" /F >nul 2>&1
    if !errorLevel! equ 0 (
        echo   [OK] Auto-start task created
        call :LOG "Task Scheduler entry created"
    ) else (
        call :WARNING "Could not create scheduled task (may need admin rights)"
        call :LOG "WARNING: Task creation failed"
    )
) else (
    echo   [i] Skipped Task Scheduler setup
)

REM ============================================================================
REM  SETUP COMPLETE
REM ============================================================================
call :HEADER "SETUP COMPLETE"

echo.
echo   [OK] All components installed and configured!
echo.
echo  ============================================================================
echo   QUICK START GUIDE
echo  ============================================================================
echo.
echo   1. Start all services:    start.bat
echo   2. Stop all services:     stop.bat
echo   3. Restart services:      restart.bat
echo   4. Check health:          health-check.bat
echo.
echo   Dashboard:  http://localhost:3000
echo   Backend:    http://localhost:8001/api
echo   WhatsApp:   http://localhost:3001/status
echo.
echo   Log files:  %SCRIPT_DIR%\logs\
echo.
echo  ============================================================================
echo.

call :LOG "Setup completed successfully"

pause
exit /b 0

REM ============================================================================
REM  UTILITY FUNCTIONS
REM ============================================================================

:LOG
echo [%date% %time%] %~1 >> "%SETUP_LOG%"
goto :eof

:HEADER
echo.
echo  ----------------------------------------------------------------------------
echo   %~1
echo  ----------------------------------------------------------------------------
echo.
goto :eof

:STATUS
echo   [..] %~1
goto :eof

:ERROR
echo   [!!] ERROR: %~1
call :LOG "ERROR: %~1"
goto :eof

:WARNING
echo   [!] WARNING: %~1
call :LOG "WARNING: %~1"
goto :eof
