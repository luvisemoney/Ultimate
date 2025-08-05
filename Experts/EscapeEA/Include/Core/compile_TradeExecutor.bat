@echo off
setlocal

set "METATRADER_PATH=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "SOURCE_FILE=TradeExecutor.mqh"
set "LOG_FILE=compile_output.log"

if not exist "%METATRADER_PATH%" (
    echo Error: MetaEditor not found at "%METATRADER_PATH%"
    pause
    exit /b 1
)

echo Compiling %SOURCE_FILE%...
"%METATRADER_PATH%" /compile:"%~dp0%SOURCE_FILE%" /log:"%~dp0%LOG_FILE%"

echo.
echo Compilation log:
if exist "%~dp0%LOG_FILE%" (
    type "%~dp0%LOG_FILE%"
    
    echo.
    findstr /i "error warning" "%~dp0%LOG_FILE%" >nul
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo WARNING: Compilation completed with warnings or errors. Check the log above for details.
    ) else (
        echo.
        echo %SOURCE_FILE% compiled successfully with no errors or warnings.
    )
) else (
    echo Error: Could not find compilation log file.
)

pause
