@echo off
setlocal

REM LiveEA compiler batch
REM Usage: build_liveea.bat [optional_full_path_to_LiveEA.mq5]

set "EA_SRC=%~dp0LiveEA.mq5"
if not "%~1"=="" (
  if exist "%~1" set "EA_SRC=%~1"
)

set "LOG=%TEMP%\LiveEA_compile.log"
if exist "%LOG%" del /f /q "%LOG%" >nul 2>&1

REM Resolve MetaEditor path
if defined METAEDITOR_PATH (
  set "METAEDITOR=%METAEDITOR_PATH%"
) else (
  set "METAEDITOR=C:\Program Files\MetaTrader 5\metaeditor64.exe"
  if not exist "%METAEDITOR%" set "METAEDITOR=C:\Program Files (x86)\MetaTrader 5\metaeditor.exe"
  if not exist "%METAEDITOR%" (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Get-ChildItem -Path 'C:\\Program Files','C:\\Program Files (x86)' -Filter metaeditor*.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"`) do set "METAEDITOR=%%A"
  )
)

if not exist "%METAEDITOR%" (
  echo [ERROR] MetaEditor not found. Set METAEDITOR_PATH env var to the full path of metaeditor64.exe
  echo Example: setx METAEDITOR_PATH "C:\\Program Files\\MetaTrader 5\\metaeditor64.exe" /M
  exit /b 1
)

echo [INFO] Compiling: "%EA_SRC%"
echo [INFO] Using MetaEditor: "%METAEDITOR%"

"%METAEDITOR%" /compile:"%EA_SRC%" /log:"%LOG%"
set ERR=%ERRORLEVEL%

echo ---------------- Compiler Log ----------------
if exist "%LOG%" (
  type "%LOG%"
) else (
  echo (no log produced)
)
echo ------------------------------------------------

exit /b %ERR%
