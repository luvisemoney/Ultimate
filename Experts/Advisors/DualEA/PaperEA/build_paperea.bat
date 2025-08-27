@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Paths
set "SRC=c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\725770E6BE34B17A6EB82115D4D83BD3\MQL5\Experts\Advisors\DualEA\PaperEA\PaperEA.mq5"
set "LOG=c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\725770E6BE34B17A6EB82115D4D83BD3\MQL5\Experts\Advisors\DualEA\PaperEA\PaperEA_build.log"

if exist "%LOG%" del /f /q "%LOG%" >nul 2>&1

REM Allow override via environment variable
if defined MT5_EDITOR if exist "%MT5_EDITOR%" set "METAEDITOR=%MT5_EDITOR%"

REM Probe common install locations if not set
if not defined METAEDITOR (
  for %%P in ("%ProgramFiles%\MetaTrader 5\metaeditor64.exe" "%ProgramFiles%\MetaTrader 5\metaeditor.exe" "%ProgramFiles(x86)%\MetaTrader 5\metaeditor.exe" "C:\Program Files\MetaQuotes\MetaTrader 5\metaeditor64.exe" "C:\Program Files (x86)\MetaQuotes\MetaTrader 5\metaeditor.exe") do (
    if not defined METAEDITOR if exist "%%~P" set "METAEDITOR=%%~P"
  )
)

REM Fallback: search Program Files recursively (can take a moment)
if not defined METAEDITOR (
  for /f "delims=" %%F in ('where /R "C:\Program Files" metaeditor*.exe 2^>nul') do (
    if not defined METAEDITOR set "METAEDITOR=%%~F"
  )
)

if not defined METAEDITOR (
  echo [BUILD] MetaEditor not found. Set MT5_EDITOR environment variable to full path of metaeditor.exe.
  exit /b 1
)

echo [BUILD] Using MetaEditor: "%METAEDITOR%"
"%METAEDITOR%" /compile:"%SRC%" /log:"%LOG%"

set ERR=%ERRORLEVEL%

echo ---- Build Log ----
if exist "%LOG%" (
  type "%LOG%"
) else (
  echo [BUILD] No log file was produced.
)

exit /b %ERR%
