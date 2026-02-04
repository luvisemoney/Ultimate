@echo off
setlocal enableextensions enabledelayedexpansion

REM DualEA Trainer Workflow (Windows)
REM - Creates Python venv under ml/.
REM - Installs requirements.
REM - Runs training to produce artifacts/.
REM - Exports policy.json with scaling fields.
REM - Touches Common Files reload marker: policy.reload

REM Resolve script directory (ml/)
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"

REM Resolve Common Files DualEA path
set "COMMON_DIR=%APPDATA%\MetaQuotes\Terminal\Common\Files\DualEA"
if not exist "%COMMON_DIR%" (
  mkdir "%COMMON_DIR%"
)

REM Create venv if missing (prefer py launcher)
if not exist ".venv" (
  echo Creating virtualenv under .venv ...
  py -3 -m venv .venv 2>nul || python -m venv .venv
)

set "PY=%SCRIPT_DIR%\.venv\Scripts\python.exe"
if not exist "%PY%" (
  set "PY=python"
)

REM Upgrade pip & install deps
"%PY%" -m pip install --upgrade pip
"%PY%" -m pip install -r requirements.txt

REM Train XGBoost model from snapshot feature_batch_*.txt files
"%PY%" snapshot_train.py
if errorlevel 1 (
  echo Snapshot training failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Export XGBoost model to ONNX format for MQL5 integration (mock version for testing)
"%PY%" snapshot_export_onnx.py
if errorlevel 1 (
  echo ONNX export failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Export policy with heuristic scales from XGBoost snapshot model (min_conf default 0.45 recommended)
"%PY%" snapshot_policy_export.py --common "%COMMON_DIR%" --model_dir "%SCRIPT_DIR%\artifacts" --min_conf 0.45
if errorlevel 1 (
  echo Policy export failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Trigger EA reload
copy /y nul "%COMMON_DIR%\policy.reload" >nul 2>&1 || ( echo.>"%COMMON_DIR%\policy.reload" )

echo [OK] Training + export complete. policy.json written and reload signaled.
popd
endlocal
