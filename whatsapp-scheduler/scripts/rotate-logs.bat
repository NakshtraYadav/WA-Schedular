@echo off
REM ============================================================================
REM  WhatsApp Scheduler - Log Rotation Script
REM  Removes log files older than 7 days
REM ============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Go up one level to main directory
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
if "%PARENT_DIR:~-1%"=="\" set "PARENT_DIR=%PARENT_DIR:~0,-1%"

set "LOG_BASE=%PARENT_DIR%\logs"
set "MAX_AGE_DAYS=7"

echo.
echo   ===========================================================================
echo              WhatsApp Scheduler - Log Rotation
echo   ===========================================================================
echo.

REM Process each log directory
for %%d in (backend frontend whatsapp system) do (
    if exist "%LOG_BASE%\%%d" (
        echo    Processing %%d logs...
        
        REM Delete files older than MAX_AGE_DAYS
        forfiles /P "%LOG_BASE%\%%d" /S /M *.log /D -%MAX_AGE_DAYS% /C "cmd /c echo    Deleted: @file && del @path" 2>nul
        
        REM Count remaining files
        set "FILE_COUNT=0"
        for %%f in ("%LOG_BASE%\%%d\*.log") do set /a FILE_COUNT+=1
        echo    [OK] %%d: !FILE_COUNT! log files remaining
    )
)

echo.
echo    [OK] Log rotation complete
echo.

if "%1"=="" pause
