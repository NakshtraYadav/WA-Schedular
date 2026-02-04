@echo off
REM ================================================
REM WhatsApp Scheduler - Stop All Services
REM ================================================

echo Stopping all WhatsApp Scheduler services...
echo.

REM Kill by window title
taskkill /FI "WINDOWTITLE eq MongoDB*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq WhatsApp Service*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Backend API*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq Frontend*" /F >nul 2>&1

REM Kill by process name (backup)
taskkill /IM "node.exe" /F >nul 2>&1
taskkill /IM "python.exe" /F >nul 2>&1

echo All services stopped.
pause
