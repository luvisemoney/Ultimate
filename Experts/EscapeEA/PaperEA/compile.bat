@echo off
setlocal

echo Compiling PaperEA.mq5...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0PaperEA.mq5" /log:"%~dp0compile_output.log"

echo.
echo Compilation log:
type "%~dp0compile_output.log"

echo.
echo Checking for .ex5 file...
dir /b "%~dp0*.ex5" 2>nul

if %ERRORLEVEL% EQU 0 (
    echo.
    echo PaperEA.ex5 was generated successfully!
) else (
    echo.
    echo Error: PaperEA.ex5 was not generated. Check the log above for errors.
)

pause
