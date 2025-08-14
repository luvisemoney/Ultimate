@echo off
setlocal enableextensions

REM Paths
set "EA=c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Advisors\DualEA\PaperEA\PaperEA.mq5"
set "LOG=%TEMP%\PaperEA_compile.log"
set "EDITOR="

REM Try to locate MetaEditor64.exe quickly via PowerShell search in common locations
for %%D in ("C:\Program Files" "C:\Program Files (x86)" "%LOCALAPPDATA%\Programs" "%LOCALAPPDATA%") do (
  if not defined EDITOR (
    for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%%~D' -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName"`) do set "EDITOR=%%F"
  )
)

if not defined EDITOR (
  echo ERROR: MetaEditor64.exe not found under common locations. Please install MetaTrader 5 or adjust PATH.
  exit /b 1
)

echo Using MetaEditor: %EDITOR%
"%EDITOR%" /compile:%EA% /log:%LOG%
set "EC=%ERRORLEVEL%"

if exist "%LOG%" (
  echo ---------------- Compiler Log ----------------
  type "%LOG%"
  echo ------------------------------------------------
) else (
  echo WARNING: Compiler log not found at %LOG%
)

exit /b %EC%
