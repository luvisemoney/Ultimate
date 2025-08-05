@echo off
setlocal

echo Compiling KnowledgeBase.mqh...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0KnowledgeBase.mqh" /log:"%~dp0compile_output.log"

echo.
echo Compilation log:
type "%~dp0compile_output.log"

:: Check if compilation was successful
findstr /i "error" "%~dp0compile_output.log" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Error: Compilation failed. Check the log above for errors.
    exit /b 1
)

findstr /i "warning" "%~dp0compile_output.log" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Warning: Compilation completed with warnings. Check the log above for details.
    exit /b 0
)

echo.
echo KnowledgeBase.mqh compiled successfully with no errors or warnings!
exit /b 0
