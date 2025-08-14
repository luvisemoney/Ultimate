@echo off
setlocal enableextensions

REM Locate MetaEditor64.exe
set "EDITOR="
for %%D in ("C:\Program Files" "C:\Program Files (x86)" "%LOCALAPPDATA%\Programs" "%LOCALAPPDATA%") do (
  if not defined EDITOR (
    for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%%~D' -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName"`) do set "EDITOR=%%F"
  )
)

if not defined EDITOR (
  echo ERROR: MetaEditor64.exe not found under common locations. Please install MetaTrader 5 or adjust PATH.
  exit /b 1
)

REM Paths
set "SRC=c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Advisors\DualEA\LiveEA\LiveEA.mq5"
set "LOG=%TEMP%\LiveEA_compile.log"

echo Using MetaEditor: %EDITOR%
"%EDITOR%" /compile:"%SRC%" /log:"%LOG%"
set "EC=%ERRORLEVEL%"

echo ---------------- Compiler Log ----------------
if exist "%LOG%" (
  type "%LOG%"
) else (
  echo WARNING: Compiler log not found at %LOG%
)
echo ------------------------------------------------

exit /b %EC%
