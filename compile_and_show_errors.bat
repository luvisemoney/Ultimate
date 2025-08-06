@echo off
setlocal enabledelayedexpansion

:: Set paths
set "MQL5_COMPILER="C:\Program Files\MetaTrader 5\MetaEditor64.exe""
set "EA_PATH=%~dp0Experts\OTC_Escape_Learning.mq5"
set "TEMP_LOG=%~dp0compile_temp.log"

:: Clear previous log
del "%TEMP_LOG%" 2>nul

echo Compiling OTC_Escape_Learning.mq5...
echo ============================================

:: Run the compiler and capture output
%MQL5_COMPILER% /compile:"%EA_PATH%" /log:"%TEMP_LOG%"

:: Check if compilation was successful
if exist "%~dp0Experts\OTC_Escape_Learning.ex5" (
    echo.
    echo ============================================
    echo  COMPILATION SUCCESSFUL!
    echo  EA file: %~dp0Experts\OTC_Escape_Learning.ex5
    echo ============================================
    exit /b 0
)

:: If we get here, there were errors
echo.
echo ============================================
echo  COMPILATION FAILED! Errors:
echo ============================================

type "%TEMP_LOG%" 2>nul

echo.
echo ============================================
echo  End of error messages
echo ============================================

:: Clean up
del "%TEMP_LOG%" 2>nul

exit /b 1
