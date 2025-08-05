@echo off
setlocal enabledelayedexpansion

set "MQL5_PATH=%ProgramFiles%\MetaTrader 5"
set "ERRORS=0"
set "TEMP_FILE=%TEMP%\escape_compile_%RANDOM%.log"

if not exist "%MQL5_PATH%\metaeditor64.exe" (
    echo ERROR: MetaEditor not found at %MQL5_PATH%\metaeditor64.exe
    exit /b 1
)

:compile_file
set "FILE_TO_COMPILE=%~1"
if "%FILE_TO_COMPILE%"=="" goto :end_compile

echo.
echo ===================================
echo Compiling %~nx1...
echo ===================================

"%MQL5_PATH%\metaeditor64.exe" /compile:"%FILE_TO_COMPILE%" /log:"%TEMP_FILE%"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to compile %~nx1
    echo ===================================
    type "%TEMP_FILE%"
    set /a ERRORS+=1
) else (
    echo [SUCCESS] %~nx1 compiled successfully
)

shift
goto :compile_file

:end_compile
if exist "%TEMP_FILE%" del /q "%TEMP_FILE%" >nul 2>&1

if %ERRORS% gtr 0 (
    echo.
    echo [!] Compilation completed with %ERRORS% error(s)
    exit /b 1
) else (
    echo.
    echo [*] All files compiled successfully
    exit /b 0
)
