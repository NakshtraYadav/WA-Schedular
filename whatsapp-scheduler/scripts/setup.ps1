#Requires -Version 5.1
<#
.SYNOPSIS
    WhatsApp Scheduler - Advanced PowerShell Setup Script
.DESCRIPTION
    Production-grade setup script with full error handling, dependency management,
    and automatic recovery capabilities for Windows 10/11.
.NOTES
    Version: 2.0
    Requires: PowerShell 5.1+, Windows 10/11
#>

param(
    [switch]$Force,
    [switch]$SkipNodeModules,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
#  CONFIGURATION
# ============================================================================
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogDir = Join-Path $ScriptDir "logs\system"
$script:SetupLog = Join-Path $LogDir "setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$script:Config = @{
    MinNodeVersion = 16
    MinPythonVersion = "3.8"
    RequiredPorts = @(3000, 3001, 8001, 27017)
    BackendPort = 8001
    FrontendPort = 3000
    WhatsAppPort = 3001
    MongoPort = 27017
}

# ============================================================================
#  UTILITY FUNCTIONS
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }
    
    Add-Content -Path $script:SetupLog -Value $logEntry -ErrorAction SilentlyContinue
    
    if (-not $Silent) {
        switch ($Level) {
            "ERROR"   { Write-Host "  [!!] $Message" -ForegroundColor Red }
            "WARNING" { Write-Host "  [!] $Message" -ForegroundColor Yellow }
            "SUCCESS" { Write-Host "  [OK] $Message" -ForegroundColor Green }
            "INFO"    { Write-Host "  [..] $Message" -ForegroundColor Cyan }
            default   { Write-Host "  $Message" }
        }
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ----------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Port {
    param([int]$Port)
    $result = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return ($null -ne $result)
}

function Stop-ProcessOnPort {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        try {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            Write-Log "Killed process $($conn.OwningProcess) on port $Port" "INFO"
        } catch {
            # Process may have already exited
        }
    }
}

function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-NodeVersion {
    try {
        $version = node -v 2>$null
        if ($version -match 'v(\d+)') {
            return [int]$Matches[1]
        }
    } catch {}
    return 0
}

function Get-PythonVersion {
    try {
        $version = python --version 2>&1
        if ($version -match '(\d+\.\d+)') {
            return $Matches[1]
        }
    } catch {}
    return "0.0"
}

# ============================================================================
#  MAIN SETUP
# ============================================================================
function Start-Setup {
    Clear-Host
    
    Write-Host ""
    Write-Host "  ============================================================================" -ForegroundColor Cyan
    Write-Host "                WhatsApp Scheduler - Production Setup" -ForegroundColor White
    Write-Host "  ============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Script Directory: $script:ScriptDir" -ForegroundColor Gray
    Write-Host "   Log File: $script:SetupLog" -ForegroundColor Gray
    Write-Host ""
    
    Write-Log "Setup started - Directory: $script:ScriptDir"
    
    # Create directories
    $directories = @(
        "backend",
        "frontend",
        "whatsapp-service",
        "logs\backend",
        "logs\frontend",
        "logs\whatsapp",
        "logs\system",
        "scripts"
    )
    
    foreach ($dir in $directories) {
        $path = Join-Path $script:ScriptDir $dir
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    Write-Log "Directory structure created" "SUCCESS"
    
    # ============================================================================
    #  PREFLIGHT CHECKS
    # ============================================================================
    Write-Header "PREFLIGHT VALIDATION"
    
    # Check Administrator
    if (Test-Administrator) {
        Write-Log "Running with administrator privileges" "SUCCESS"
    } else {
        Write-Log "Running without administrator privileges - some features may be limited" "WARNING"
    }
    
    # Check Windows version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-Log "Windows: $($osInfo.Caption) $($osInfo.Version)" "SUCCESS"
    
    # ============================================================================
    #  NODE.JS VALIDATION
    # ============================================================================
    Write-Header "NODE.JS VALIDATION"
    
    if (-not (Test-Command "node")) {
        Write-Log "Node.js is not installed!" "ERROR"
        Write-Host ""
        Write-Host "   To fix this:" -ForegroundColor Yellow
        Write-Host "   1. Download Node.js LTS from: https://nodejs.org/"
        Write-Host "   2. Run the installer (check 'Add to PATH')"
        Write-Host "   3. Restart this script"
        Write-Host ""
        throw "Node.js not found"
    }
    
    $nodeVersion = Get-NodeVersion
    if ($nodeVersion -lt $script:Config.MinNodeVersion) {
        Write-Log "Node.js version $nodeVersion is below minimum $($script:Config.MinNodeVersion)" "WARNING"
    } else {
        Write-Log "Node.js v$nodeVersion" "SUCCESS"
    }
    
    if (-not (Test-Command "npm")) {
        Write-Log "npm not found!" "ERROR"
        throw "npm not found"
    }
    $npmVersion = (npm -v 2>$null).Trim()
    Write-Log "npm v$npmVersion" "SUCCESS"
    
    # Install yarn if missing
    if (-not (Test-Command "yarn")) {
        Write-Log "Installing yarn..." "INFO"
        npm install -g yarn 2>$null
    }
    if (Test-Command "yarn") {
        $yarnVersion = (yarn -v 2>$null).Trim()
        Write-Log "yarn v$yarnVersion" "SUCCESS"
    }
    
    # ============================================================================
    #  PYTHON VALIDATION
    # ============================================================================
    Write-Header "PYTHON VALIDATION"
    
    $pythonCmd = $null
    foreach ($cmd in @("python", "python3", "py")) {
        if (Test-Command $cmd) {
            $pythonCmd = $cmd
            break
        }
    }
    
    if (-not $pythonCmd) {
        Write-Log "Python is not installed!" "ERROR"
        Write-Host ""
        Write-Host "   To fix this:" -ForegroundColor Yellow
        Write-Host "   1. Download Python from: https://www.python.org/downloads/"
        Write-Host "   2. Run installer - CHECK 'Add Python to PATH'"
        Write-Host "   3. Restart this script"
        Write-Host ""
        throw "Python not found"
    }
    
    $pythonVersion = Get-PythonVersion
    Write-Log "Python $pythonVersion (using: $pythonCmd)" "SUCCESS"
    
    # Check pip
    try {
        & $pythonCmd -m pip --version 2>$null | Out-Null
        Write-Log "pip available" "SUCCESS"
    } catch {
        Write-Log "Installing pip..." "INFO"
        & $pythonCmd -m ensurepip --upgrade 2>$null
    }
    
    # ============================================================================
    #  MONGODB VALIDATION
    # ============================================================================
    Write-Header "MONGODB VALIDATION"
    
    $mongoRunning = $false
    
    # Check service
    $mongoService = Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue
    if ($mongoService) {
        if ($mongoService.Status -eq "Running") {
            Write-Log "MongoDB service is running" "SUCCESS"
            $mongoRunning = $true
        } else {
            Write-Log "Starting MongoDB service..." "INFO"
            try {
                Start-Service -Name "MongoDB" -ErrorAction Stop
                Write-Log "MongoDB service started" "SUCCESS"
                $mongoRunning = $true
            } catch {
                Write-Log "Could not start MongoDB service" "WARNING"
            }
        }
    }
    
    if (-not $mongoRunning) {
        # Check if port is in use (might be running manually)
        if (Test-Port $script:Config.MongoPort) {
            Write-Log "MongoDB detected on port $($script:Config.MongoPort)" "SUCCESS"
            $mongoRunning = $true
        } else {
            Write-Log "MongoDB not running locally - ensure Atlas connection or start MongoDB" "WARNING"
        }
    }
    
    # ============================================================================
    #  PORT VALIDATION
    # ============================================================================
    Write-Header "PORT VALIDATION"
    
    foreach ($port in $script:Config.RequiredPorts) {
        if (Test-Port $port) {
            Write-Log "Port $port is in use" "WARNING"
            if ($Force) {
                Stop-ProcessOnPort $port
                Start-Sleep -Seconds 1
            }
        } else {
            Write-Log "Port $port is available" "SUCCESS"
        }
    }
    
    # ============================================================================
    #  BACKEND SETUP
    # ============================================================================
    Write-Header "BACKEND SETUP"
    
    $backendDir = Join-Path $script:ScriptDir "backend"
    Push-Location $backendDir
    
    try {
        # Create virtual environment
        if (-not (Test-Path "venv")) {
            Write-Log "Creating virtual environment..." "INFO"
            & $pythonCmd -m venv venv
        }
        Write-Log "Virtual environment ready" "SUCCESS"
        
        # Activate and install dependencies
        Write-Log "Installing Python dependencies..." "INFO"
        $activateScript = Join-Path $backendDir "venv\Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            & $activateScript
        }
        
        $requirements = Join-Path $backendDir "requirements.txt"
        if (Test-Path $requirements) {
            & $pythonCmd -m pip install -r $requirements -q 2>$null
        } else {
            & $pythonCmd -m pip install fastapi uvicorn python-dotenv motor pymongo pydantic httpx apscheduler pytz tzlocal -q 2>$null
        }
        Write-Log "Python dependencies installed" "SUCCESS"
        
        # Create .env if missing
        $envFile = Join-Path $backendDir ".env"
        if (-not (Test-Path $envFile)) {
            @"
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
HOST=0.0.0.0
PORT=8001
"@ | Set-Content $envFile
            Write-Log "Created backend .env file" "SUCCESS"
        } else {
            Write-Log "Backend .env file exists" "SUCCESS"
        }
    }
    finally {
        Pop-Location
    }
    
    # ============================================================================
    #  WHATSAPP SERVICE SETUP
    # ============================================================================
    Write-Header "WHATSAPP SERVICE SETUP"
    
    $waDir = Join-Path $script:ScriptDir "whatsapp-service"
    Push-Location $waDir
    
    try {
        if (-not $SkipNodeModules -or -not (Test-Path "node_modules")) {
            Write-Log "Installing WhatsApp service dependencies (this may take a few minutes)..." "INFO"
            
            $maxRetries = 3
            $retry = 0
            $success = $false
            
            while (-not $success -and $retry -lt $maxRetries) {
                $retry++
                try {
                    if (Test-Command "yarn") {
                        yarn install --silent 2>$null
                    } else {
                        npm install --legacy-peer-deps --silent 2>$null
                    }
                    $success = $true
                } catch {
                    if ($retry -lt $maxRetries) {
                        Write-Log "Retry $retry/$maxRetries..." "WARNING"
                        Remove-Item -Path "node_modules" -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path "package-lock.json" -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            if ($success) {
                Write-Log "WhatsApp service dependencies installed" "SUCCESS"
            } else {
                Write-Log "WhatsApp service dependencies may have issues" "WARNING"
            }
        } else {
            Write-Log "WhatsApp service dependencies exist (skipped)" "SUCCESS"
        }
    }
    finally {
        Pop-Location
    }
    
    # ============================================================================
    #  FRONTEND SETUP
    # ============================================================================
    Write-Header "FRONTEND SETUP"
    
    $frontendDir = Join-Path $script:ScriptDir "frontend"
    Push-Location $frontendDir
    
    try {
        if (-not $SkipNodeModules -or -not (Test-Path "node_modules")) {
            Write-Log "Installing frontend dependencies (this may take several minutes)..." "INFO"
            
            $maxRetries = 3
            $retry = 0
            $success = $false
            
            while (-not $success -and $retry -lt $maxRetries) {
                $retry++
                try {
                    if (Test-Command "yarn") {
                        yarn install --silent 2>$null
                    } else {
                        npm install --legacy-peer-deps --silent 2>$null
                    }
                    $success = $true
                } catch {
                    if ($retry -lt $maxRetries) {
                        Write-Log "Retry $retry/$maxRetries..." "WARNING"
                        Remove-Item -Path "node_modules" -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path "package-lock.json" -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            if ($success) {
                Write-Log "Frontend dependencies installed" "SUCCESS"
            } else {
                Write-Log "Frontend dependencies may have issues" "WARNING"
            }
        } else {
            Write-Log "Frontend dependencies exist (skipped)" "SUCCESS"
        }
        
        # Create .env if missing
        $envFile = Join-Path $frontendDir ".env"
        if (-not (Test-Path $envFile)) {
            "REACT_APP_BACKEND_URL=http://localhost:8001" | Set-Content $envFile
            Write-Log "Created frontend .env file" "SUCCESS"
        } else {
            Write-Log "Frontend .env file exists" "SUCCESS"
        }
    }
    finally {
        Pop-Location
    }
    
    # ============================================================================
    #  CREATE DEPENDENCY LOCK
    # ============================================================================
    Write-Header "FINALIZING"
    
    $lockFile = Join-Path $script:ScriptDir "dependency-lock.txt"
    @"
# WhatsApp Scheduler - Dependency Lock File
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

[node]
version=$(node -v 2>$null)

[npm]
version=$(npm -v 2>$null)

[python]
version=$pythonVersion

[setup]
completed=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@ | Set-Content $lockFile
    Write-Log "Dependency versions locked" "SUCCESS"
    
    # ============================================================================
    #  SETUP COMPLETE
    # ============================================================================
    Write-Host ""
    Write-Host "  ============================================================================" -ForegroundColor Green
    Write-Host "                       SETUP COMPLETE!" -ForegroundColor White
    Write-Host "  ============================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Quick Start Commands:" -ForegroundColor Cyan
    Write-Host "   ---------------------------------------------------------------------------"
    Write-Host "   Start all services:    .\start.bat" -ForegroundColor White
    Write-Host "   Stop all services:     .\stop.bat" -ForegroundColor White
    Write-Host "   Restart services:      .\restart.bat" -ForegroundColor White
    Write-Host "   Check health:          .\health-check.bat" -ForegroundColor White
    Write-Host "   Run watchdog:          .\watchdog.bat" -ForegroundColor White
    Write-Host ""
    Write-Host "   URLs:" -ForegroundColor Cyan
    Write-Host "   ---------------------------------------------------------------------------"
    Write-Host "   Dashboard:             http://localhost:3000" -ForegroundColor White
    Write-Host "   Backend API:           http://localhost:8001/api" -ForegroundColor White
    Write-Host "   WhatsApp Service:      http://localhost:3001/status" -ForegroundColor White
    Write-Host ""
    Write-Host "  ============================================================================" -ForegroundColor Green
    Write-Host ""
    
    Write-Log "Setup completed successfully"
}

# Run setup
try {
    Start-Setup
} catch {
    Write-Log $_.Exception.Message "ERROR"
    Write-Host ""
    Write-Host "  Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
