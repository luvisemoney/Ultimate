@echo off
setlocal

echo Compiling LiveEA.mq5...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0LiveEA.mq5" /log:"%~dp0compile_output.log"

echo.
echo Compilation log:
type "%~dp0compile_output.log"

echo.
echo Checking for .ex5 file...
if exist "%~dp0LiveEA.ex5" (
    echo.
    echo LiveEA.ex5 was generated successfully!
) else (
    echo.
    echo Error: LiveEA.ex5 was not generated. Check the log above for errors.
)

echo.
pause
