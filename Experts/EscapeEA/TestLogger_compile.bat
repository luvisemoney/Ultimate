@echo off
setlocal

set "METATRADER_PATH=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "SOURCE_FILE=TestLogger.mq5"
set "LOG_FILE=TestLogger_compile.log"

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

echo.
echo Checking for .ex5 file...
dir /b "%~dp0*.ex5" 2>nul

if %ERRORLEVEL% EQU 0 (
    echo.
    echo %SOURCE_FILE%.ex5 was generated successfully!
) else (
    echo.
    echo Error: %SOURCE_FILE%.ex5 was not generated. Check the log above for errors.
)

pause
