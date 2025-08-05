@echo off
setlocal enabledelayedexpansion

:: Clear the screen
cls

:: Set up variables
set "error_count=0"
set "success_count=0"
set "start_time=%time%"
set "log_file=%temp%\EscapeEA_compile_%random%.log"

echo Compiling files...
echo =================

:: Function to check compilation result
:check_compile
if %errorlevel% neq 0 (
    echo [ERROR] Failed to compile %~1
    type "%log_file%" 2>nul
    set /a error_count+=1
) else (
    echo [OK] %~1 compiled successfully
    set /a success_count+=1
)

del /q "%log_file%" 2>nul

goto :eof

:: Main compilation starts here

:: Compile Logger.mqh
echo.
echo Compiling Logger.mqh...
"%ProgramFiles%\MetaTrader 5\metaeditor64.exe" /compile:"%cd%\Include\Utils\Logger.mqh" /log:"%log_file%"
call :check_compile "Logger.mqh"

:: Compile AdvancedRiskManager.mqh
echo.
echo Compiling AdvancedRiskManager.mqh...
"%ProgramFiles%\MetaTrader 5\metaeditor64.exe" /compile:"%cd%\Include\Core\AdvancedRiskManager.mqh" /log:"%log_file%"
call :check_compile "AdvancedRiskManager.mqh"

:: Show summary
echo.
echo =================
echo Compilation Summary
echo =================
echo Start Time: %start_time%
echo End Time:   %time%
echo.
echo Successfully compiled: %success_count% file(s)
if %error_count% GTR 0 (
    echo Failed to compile: %error_count% file(s)
    echo.
    echo Please check the error messages above for details.
    exit /b 1
) else (
    echo All files compiled successfully!
    exit /b 0
)
