@echo off
setlocal enabledelayedexpansion

:: Set script directory and log file
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%compile_log.txt"

:: Set compiler path
set "MQL5_COMPILER=C:\Program Files\MetaTrader 5\MetaEditor64.exe"

if not exist "%MQL5_COMPILER%" (
    echo Error: MetaEditor not found at %MQL5_COMPILER%
    echo Please check your MetaTrader 5 installation.
    pause
    exit /b 1
)

echo Compiling OTC_Escape_Learning EA...
echo ============================================

echo [%date% %time%] Starting compilation... > %LOG_FILE%

:: Compile the EA
"%MQL5_COMPILER%" /compile:"%SCRIPT_DIR%Experts\OTC_Escape_Learning.mq5" /log:%LOG_FILE% /inc:"%SCRIPT_DIR%Include"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo  Compilation successful!
    echo  EA file: %SCRIPT_DIR%Experts\OTC_Escape_Learning.ex5
    echo  Log file: %LOG_FILE%
    echo ============================================
) else (
    echo.
    echo ============================================
    echo  Compilation failed with error code %ERRORLEVEL%
    echo  Please check the log file: %LOG_FILE%
    echo ============================================
    
    :: Show the last 10 lines of the log
    echo.
    echo Last 10 lines of the log:
    echo --------------------------------------------
    type %LOG_FILE% | findstr /n /r "." | findstr /r "^[0-9]*:.*[Ee]rror\|^[0-9]*:.*[Ww]arning"
)

pause
