@echo off
REM ============================================================================
REM JAILBREAK COMPONENT 1: Main EA Foundation Compilation
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK COMPONENT 1: MAIN EA FOUNDATION
echo DualEA_Foundation.mq5 Compilation
echo ===============================================================================
echo.

set "MT5_PATH=C:\Program Files\MetaTrader 5"
set "MT5_COMPILER=%MT5_PATH%\metaeditor64.exe"
set "PROJECT_PATH=%~dp0"
set "SOURCE_FILE=%PROJECT_PATH%DualEA_Foundation.mq5"
set "LOG_FILE=%PROJECT_PATH%compile_foundation_detailed.log"

echo Compiling: %SOURCE_FILE%
echo Log file: %LOG_FILE%
echo.

if not exist "%MT5_COMPILER%" (
    echo ERROR: MetaEditor not found at %MT5_COMPILER%
    pause
    exit /b 1
)

if not exist "%SOURCE_FILE%" (
    echo ERROR: Source file not found: %SOURCE_FILE%
    pause
    exit /b 1
)

echo Starting compilation...
"%MT5_COMPILER%" /compile:"%SOURCE_FILE%" /log:"%LOG_FILE%"

if !errorlevel! equ 0 (
    echo.
    echo ✓ SUCCESS: DualEA_Foundation.mq5 compiled successfully!
    echo ✓ The main EA is ready for deployment.
    echo.
) else (
    echo.
    echo ✗ FAILED: DualEA_Foundation.mq5 compilation failed!
    echo ✗ Please check the log file for details: %LOG_FILE%
    echo.
)

echo Press any key to continue...
pause >nul