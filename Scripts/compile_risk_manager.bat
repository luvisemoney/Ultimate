@echo off
setlocal

set "MQL5_PATH=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "FILE_PATH=%~dp0..\Experts\EscapeEA\Include\Core\AdvancedRiskManager.mqh"
set "LOG_PATH=%~dp0..\Logs\AdvancedRiskManager_compile.log"

echo Compiling AdvancedRiskManager.mqh...
"%MQL5_PATH%" /compile:"%FILE_PATH%" /log:"%LOG_PATH%"

echo.
echo Compilation log:
type "%LOG_PATH%"

findstr /i "error" "%LOG_PATH%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Error: Compilation failed. Check the log for details.
    pause
    exit /b 1
)

findstr /i "warning" "%LOG_PATH%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Warning: Compilation completed with warnings. Check the log for details.
    pause
    exit /b 0
)

echo.
echo AdvancedRiskManager.mqh compiled successfully with no errors or warnings!
pause
exit /b 0
