@echo off
setlocal enableextensions enabledelayedexpansion

rem ==============================================
rem  MT5 Compile Script
rem  Usage:
rem    compile_mt5.bat "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
rem  If not provided, defaults to the above path.
rem  Logs: build\logs\*.log
rem  EAs:  CascadeGreepEA.mq5, CascadeGreepMasterEA.mq5
rem ==============================================

set "METAEDITOR=%~1"
if not defined METAEDITOR set "METAEDITOR=C:\Program Files\MetaTrader 5\MetaEditor64.exe"

if not exist "%METAEDITOR%" (
  echo [ERROR] MetaEditor64.exe not found at "%METAEDITOR%"
  echo         Pass the path as the first argument, e.g.
  echo         compile_mt5.bat "C:\\Program Files\\MetaTrader 5\\MetaEditor64.exe"
  exit /b 1
)

set "ROOT=%~dp0.."
pushd "%ROOT%" >nul 2>&1

set "BUILD=build"
set "LOGDIR=%BUILD%\logs"
if not exist "%BUILD%" mkdir "%BUILD%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

set "SRC1=CascadeGreepEA.mq5"
set "SRC2=CascadeGreepMasterEA.mq5"
set "LOG1=%LOGDIR%\CascadeGreepEA.log"
set "LOG2=%LOGDIR%\CascadeGreepMasterEA.log"
set "OUT1=CascadeGreepEA.ex5"
set "OUT2=CascadeGreepMasterEA.ex5"

echo [INFO] Using MetaEditor: "%METAEDITOR%"
echo [INFO] Project root: "%CD%"

if not exist "%SRC1%" (
  echo [ERROR] Source not found: %SRC1%
  popd >nul 2>&1
  exit /b 2
)
if not exist "%SRC2%" (
  echo [ERROR] Source not found: %SRC2%
  popd >nul 2>&1
  exit /b 3
)

rem --- Compile Worker EA ---
"%METAEDITOR%" /compile:"%CD%\%SRC1%" /log:"%CD%\%LOG1%"
set "ERR1=%ERRORLEVEL%"
if exist "%OUT1%" (
  echo [OK] Built %OUT1%
) else (
  echo [WARN] %OUT1% not found in project dir. See log: %LOG1%
)

rem --- Compile Master EA ---
"%METAEDITOR%" /compile:"%CD%\%SRC2%" /log:"%CD%\%LOG2%"
set "ERR2=%ERRORLEVEL%"
if exist "%OUT2%" (
  echo [OK] Built %OUT2%
) else (
  echo [WARN] %OUT2% not found in project dir. See log: %LOG2%
)

if not "%ERR1%"=="0" (
  echo [ERROR] MetaEditor returned errorlevel %ERR1% for %SRC1% (see %LOG1%)
)
if not "%ERR2%"=="0" (
  echo [ERROR] MetaEditor returned errorlevel %ERR2% for %SRC2% (see %LOG2%)
)

if "%ERR1%"=="0" if "%ERR2%"=="0" (
  echo [DONE] Compilation requests submitted successfully.
  popd >nul 2>&1
  exit /b 0
) else (
  echo [DONE] Compilation finished with errors. Check logs under %LOGDIR%.
  popd >nul 2>&1
  exit /b 5
)
