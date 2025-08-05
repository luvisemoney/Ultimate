@echo off
setlocal

echo Compiling MockAdvancedStrategy.mqh...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0MockAdvancedStrategy.mqh" /log:"%~dp0compile_output.log"

echo.
echo Compilation log:
type "%~dp0compile_output.log"

echo.
echo Checking for .ex5 file...
if exist "%~dp0MockAdvancedStrategy.ex5" (
    echo.
    echo MockAdvancedStrategy.ex5 was generated successfully!
) else (
    echo.
    echo Error: MockAdvancedStrategy.ex5 was not generated. Check the log above for errors.
)

echo.
pause
