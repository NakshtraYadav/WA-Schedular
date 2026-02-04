#Requires -Version 5.1
<#
.SYNOPSIS
    WhatsApp Scheduler - Advanced Watchdog Service
.DESCRIPTION
    Self-healing watchdog that monitors all services, performs automatic
    restarts, detects resource issues, and maintains system stability.
.NOTES
    Version: 2.0
    Requires: PowerShell 5.1+, Windows 10/11
#>

param(
    [int]$CheckInterval = 30,
    [int]$MaxFailures = 3,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

# ============================================================================
#  CONFIGURATION
# ============================================================================
$script:ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:LogDir = Join-Path $ScriptDir "logs\system"
$script:WatchdogLog = Join-Path $LogDir "watchdog.log"

$script:Config = @{
    BackendPort = 8001
    FrontendPort = 3000
    WhatsAppPort = 3001
    MongoPort = 27017
    MemoryWarningMB = 200
    CpuWarningPercent = 95
    DiskWarningGB = 1
}

$script:FailureCounters = @{
    Backend = 0
    Frontend = 0
    WhatsApp = 0
}

# ============================================================================
#  UTILITY FUNCTIONS
# ============================================================================
function Write-WatchdogLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }
    
    Add-Content -Path $script:WatchdogLog -Value $logEntry -ErrorAction SilentlyContinue
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        "RESTART" { "Magenta" }
        default { "White" }
    }
    
    Write-Host "  [$timestamp] $Message" -ForegroundColor $color
}

function Test-ServiceHealth {
    param(
        [string]$Name,
        [string]$Url,
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Stop-ProcessOnPort {
    param([int]$Port)
    
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        try {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Restart-BackendService {
    Write-WatchdogLog "Restarting Backend API..." "RESTART"
    
    Stop-ProcessOnPort $script:Config.BackendPort
    Start-Sleep -Seconds 2
    
    $backendDir = Join-Path $script:ScriptDir "backend"
    $activateScript = Join-Path $backendDir "venv\Scripts\activate.bat"
    $logFile = Join-Path $script:ScriptDir "logs\backend\api_watchdog.log"
    
    if (Test-Path $activateScript) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d `"$backendDir`" && call venv\Scripts\activate.bat && python -m uvicorn server:app --host 0.0.0.0 --port $($script:Config.BackendPort) >> `"$logFile`" 2>&1" -WindowStyle Hidden
    } else {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d `"$backendDir`" && python -m uvicorn server:app --host 0.0.0.0 --port $($script:Config.BackendPort) >> `"$logFile`" 2>&1" -WindowStyle Hidden
    }
    
    Write-WatchdogLog "Backend restart command issued" "INFO"
}

function Restart-WhatsAppService {
    Write-WatchdogLog "Restarting WhatsApp Service..." "RESTART"
    
    Stop-ProcessOnPort $script:Config.WhatsAppPort
    Start-Sleep -Seconds 2
    
    $waDir = Join-Path $script:ScriptDir "whatsapp-service"
    $logFile = Join-Path $script:ScriptDir "logs\whatsapp\service_watchdog.log"
    
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d `"$waDir`" && node index.js >> `"$logFile`" 2>&1" -WindowStyle Hidden
    
    Write-WatchdogLog "WhatsApp service restart command issued" "INFO"
}

function Restart-FrontendService {
    Write-WatchdogLog "Restarting Frontend..." "RESTART"
    
    Stop-ProcessOnPort $script:Config.FrontendPort
    Start-Sleep -Seconds 2
    
    $frontendDir = Join-Path $script:ScriptDir "frontend"
    $logFile = Join-Path $script:ScriptDir "logs\frontend\react_watchdog.log"
    
    $env:BROWSER = "none"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d `"$frontendDir`" && set BROWSER=none && npm start >> `"$logFile`" 2>&1" -WindowStyle Hidden
    
    Write-WatchdogLog "Frontend restart command issued" "INFO"
}

function Get-SystemMetrics {
    $metrics = @{
        FreeMemoryMB = 0
        CpuPercent = 0
        FreeDiskGB = 0
    }
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $metrics.FreeMemoryMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
        
        $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
        $metrics.CpuPercent = [math]::Round($cpu.Average, 0)
        
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $metrics.FreeDiskGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    } catch {}
    
    return $metrics
}

# ============================================================================
#  MAIN WATCHDOG LOOP
# ============================================================================
function Start-Watchdog {
    Clear-Host
    
    Write-Host ""
    Write-Host "  ============================================================================" -ForegroundColor Magenta
    Write-Host "              WhatsApp Scheduler - Watchdog Service" -ForegroundColor White
    Write-Host "  ============================================================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "   Check Interval: $CheckInterval seconds"
    Write-Host "   Max Failures: $MaxFailures before restart"
    Write-Host "   Press CTRL+C to stop"
    Write-Host ""
    Write-Host "  ----------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-WatchdogLog "Watchdog started - Interval: ${CheckInterval}s, MaxFailures: $MaxFailures"
    
    while ($true) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $status = @()
        $anyRestart = $false
        
        # Check Backend
        $backendHealthy = Test-ServiceHealth -Name "Backend" -Url "http://localhost:$($script:Config.BackendPort)/api/"
        if ($backendHealthy) {
            $script:FailureCounters.Backend = 0
            $status += "Backend:OK"
        } else {
            $script:FailureCounters.Backend++
            $status += "Backend:FAIL($($script:FailureCounters.Backend))"
            
            if ($script:FailureCounters.Backend -ge $MaxFailures) {
                Restart-BackendService
                $script:FailureCounters.Backend = 0
                $anyRestart = $true
            }
        }
        
        # Check WhatsApp
        $waHealthy = Test-ServiceHealth -Name "WhatsApp" -Url "http://localhost:$($script:Config.WhatsAppPort)/health"
        if ($waHealthy) {
            $script:FailureCounters.WhatsApp = 0
            $status += "WhatsApp:OK"
        } else {
            $script:FailureCounters.WhatsApp++
            $status += "WhatsApp:FAIL($($script:FailureCounters.WhatsApp))"
            
            if ($script:FailureCounters.WhatsApp -ge $MaxFailures) {
                Restart-WhatsAppService
                $script:FailureCounters.WhatsApp = 0
                $anyRestart = $true
            }
        }
        
        # Check Frontend
        $feHealthy = Test-ServiceHealth -Name "Frontend" -Url "http://localhost:$($script:Config.FrontendPort)/"
        if ($feHealthy) {
            $script:FailureCounters.Frontend = 0
            $status += "Frontend:OK"
        } else {
            $script:FailureCounters.Frontend++
            $status += "Frontend:FAIL($($script:FailureCounters.Frontend))"
            
            if ($script:FailureCounters.Frontend -ge $MaxFailures) {
                Restart-FrontendService
                $script:FailureCounters.Frontend = 0
                $anyRestart = $true
            }
        }
        
        # Check system resources
        $metrics = Get-SystemMetrics
        if ($metrics.FreeMemoryMB -lt $script:Config.MemoryWarningMB -and $metrics.FreeMemoryMB -gt 0) {
            $status += "MEM:LOW($($metrics.FreeMemoryMB)MB)"
            Write-WatchdogLog "Low memory warning: $($metrics.FreeMemoryMB) MB free" "WARNING"
        }
        
        if ($metrics.CpuPercent -gt $script:Config.CpuWarningPercent) {
            $status += "CPU:HIGH($($metrics.CpuPercent)%)"
            Write-WatchdogLog "High CPU warning: $($metrics.CpuPercent)%" "WARNING"
        }
        
        # Display status
        $statusLine = "[$timestamp] " + ($status -join " | ")
        
        $allOk = $backendHealthy -and $waHealthy -and $feHealthy
        if ($allOk -and -not $anyRestart) {
            Write-Host "  $statusLine" -ForegroundColor Green
        } elseif ($anyRestart) {
            Write-Host "  $statusLine [RESTARTING]" -ForegroundColor Magenta
        } else {
            Write-Host "  $statusLine" -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds $CheckInterval
    }
}

# Run watchdog
try {
    Start-Watchdog
} catch {
    Write-WatchdogLog "Watchdog error: $($_.Exception.Message)" "ERROR"
}
