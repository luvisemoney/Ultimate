@echo off
setlocal enabledelayedexpansion

set "MQL5_PATH=%ProgramFiles%\MetaTrader 5"
set "LOG_FILE=logger_errors.log"
set "SOURCE_FILE=Include\Utils\Logger.mqh"

echo Compiling %SOURCE_FILE%...
echo.

"%MQL5_PATH%\metaeditor64.exe" /compile:"%cd%\%SOURCE_FILE%" /log:"%cd%\%LOG_FILE%"

echo.
echo ===== COMPILATION COMPLETE =====
type "%LOG_FILE%"
echo.
echo ===== END OF LOG =====

del "%LOG_FILE%" >nul 2>&1
