@echo off
REM === Compile Single Integration Test ===
REM Usage: compile_single_test.bat <TestFile.mq5>

setlocal
set MQL5_COMPILER="C:\Program Files\MetaTrader 5\metaeditor64.exe"

if "%1"=="" (
    echo ERROR: No test file specified.
    exit /b 1
)

REM Compile the specified test file
%MQL5_COMPILER% /compile:"%~dp0%1" /log
if errorlevel 1 (
    echo ERROR: Failed to compile %1
    exit /b 1
) else (
    echo SUCCESS: %1 compiled successfully.
)

endlocal
