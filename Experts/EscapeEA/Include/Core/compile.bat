@echo off
setlocal

echo Compiling AdvancedRiskManager.mqh...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0AdvancedRiskManager.mqh" /log:"%~dp0compile_output.log"

echo.
echo Compilation log:
type "%~dp0compile_output.log"

echo.
if exist "%~dp0*.ex5" (
    echo AdvancedRiskManager compiled successfully!
) else (
    echo Warning: No .ex5 file was generated. This is expected for include files.
)

pause
