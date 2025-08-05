@echo off
REM Batch script to compile all .mqh and .mq5 files in Include and subdirectories
setlocal enabledelayedexpansion
set MQL5_EDITOR="C:\Program Files\MetaTrader 5\MetaEditor64.exe"
set BASEDIR=%~dp0
for /r "%BASEDIR%" %%f in (*.mqh *.mq5) do (
    echo Compiling %%f
    %MQL5_EDITOR% /compile:%%f
)
echo Compilation complete.
pause
