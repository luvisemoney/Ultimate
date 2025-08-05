@echo off
setlocal enabledelayedexpansion

set "MQL5_PATH=%ProgramFiles%\MetaTrader 5"
set "LOG_FILE=%TEMP%\logger_compile_%RANDOM%.log"
set "ERRORS=0"

if not exist "%MQL5_PATH%\metaeditor64.exe" (
    echo ERROR: MetaEditor not found at %MQL5_PATH%\metaeditor64.exe
    exit /b 1
)

echo.
echo ===================================
echo Compiling Logger.mqh with detailed output...
echo ===================================
echo.

"%MQL5_PATH%\metaeditor64.exe" /compile:"%cd%\Include\Utils\Logger.mqh" /log:"%LOG_FILE%"

if %errorlevel% neq 0 (
    echo [ERROR] Compilation failed with error code %errorlevel%
    set /a ERRORS+=1
) else (
    echo [SUCCESS] Compilation completed with no errors
)

echo.
echo ===================================
echo Compilation Log:
echo ===================================
type "%LOG_FILE%"

echo.
echo ===================================
echo End of compilation log
echo ===================================

if exist "%LOG_FILE%" del /q "%LOG_FILE%" >nul 2>&1

exit /b %ERRORS%
