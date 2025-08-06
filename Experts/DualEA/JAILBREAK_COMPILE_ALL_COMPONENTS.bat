@echo off
REM ============================================================================
REM JAILBREAK LEVEL 5 - INSTITUTIONAL GRADE COMPILATION SYSTEM
REM Expert Panel: Maximum Paranoia + Advanced Features
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK LEVEL 5 EA - COMPREHENSIVE COMPILATION SYSTEM
echo Institutional Grade Security-First Approach
echo ===============================================================================
echo.

REM Set MetaTrader 5 paths
set "MT5_PATH=C:\Program Files\MetaTrader 5"
set "MT5_COMPILER=%MT5_PATH%\metaeditor64.exe"
set "PROJECT_PATH=%~dp0"
set "LOG_FILE=%PROJECT_PATH%JAILBREAK_COMPILATION_LOG.txt"

REM Initialize log file
echo JAILBREAK COMPILATION LOG - %date% %time% > "%LOG_FILE%"
echo =============================================================================== >> "%LOG_FILE%"

REM Check if MetaEditor exists
if not exist "%MT5_COMPILER%" (
    echo ERROR: MetaEditor not found at %MT5_COMPILER%
    echo Please update MT5_PATH variable in this script
    echo ERROR: MetaEditor not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo MetaEditor found: %MT5_COMPILER%
echo MetaEditor found: %MT5_COMPILER% >> "%LOG_FILE%"
echo.

REM Component compilation counters

REM =========================
REM DYNAMIC MQ5 COMPILATION
REM =========================
setlocal enabledelayedexpansion
set "MT5_PATH=C:\Program Files\MetaTrader 5"
set "MT5_COMPILER=%MT5_PATH%\metaeditor64.exe"
set "PROJECT_PATH=%~dp0"
set "LOG_FILE=%PROJECT_PATH%JAILBREAK_COMPILATION_LOG.txt"

REM Initialize log file
echo JAILBREAK COMPILATION LOG - %date% %time% > "%LOG_FILE%"
echo =============================================================================== >> "%LOG_FILE%"

REM Find and compile all .mq5 files recursively

for /r "%PROJECT_PATH%" %%F in (*.mq5) do (
    setlocal enabledelayedexpansion
    set "COMPILE_LOG=%PROJECT_PATH%compile_%%~nF.log"
    echo Compiling %%~nxF ...
    echo Compiling %%~nxF ... >> "%LOG_FILE%"
    "%MT5_COMPILER%" /compile:"%%F" /log:"!COMPILE_LOG!"
    REM Wait for log file to be created
    set /a waitCount=0
    :waitForLog
    if not exist "!COMPILE_LOG!" (
        set /a waitCount+=1
        if !waitCount! gtr 50 (
            echo ERROR: Log file !COMPILE_LOG! not created for %%~nxF >> "%LOG_FILE%"
            goto :continueLoop
        )
        timeout /t 1 >nul
        goto :waitForLog
    )
    REM Check for errors
    findstr /i ": error" "!COMPILE_LOG!" >nul
    if !errorlevel! equ 0 (
        echo ✗ FAILED: %%~nxF compilation errors detected
        echo ✗ FAILED: %%~nxF compilation errors detected >> "%LOG_FILE%"
        findstr /i ": error" "!COMPILE_LOG!" >> "%LOG_FILE%"
    ) else (
        echo ✓ SUCCESS: %%~nxF compiled with no errors
        echo ✓ SUCCESS: %%~nxF compiled with no errors >> "%LOG_FILE%"
    )
    REM Check for warnings
    findstr /i ": warning" "!COMPILE_LOG!" >nul
    if !errorlevel! equ 0 (
        echo ⚠️  WARNINGS: %%~nxF has warnings
        echo ⚠️  WARNINGS: %%~nxF has warnings >> "%LOG_FILE%"
        findstr /i ": warning" "!COMPILE_LOG!" >> "%LOG_FILE%"
    )
    echo. >> "%LOG_FILE%"
    :continueLoop
    endlocal
)

echo ===============================================================================
echo DYNAMIC JAILBREAK COMPILATION SUMMARY
echo ===============================================================================
echo Log file saved to: %LOG_FILE%
echo Compilation completed at: %date% %time%
echo Press any key to continue...
pause >nul