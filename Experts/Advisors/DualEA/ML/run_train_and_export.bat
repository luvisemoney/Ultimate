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

REM Train model (tweak epochs/batch/splits/model as needed)
"%PY%" train.py --common "%COMMON_DIR%" --epochs 10 --batch 256 --splits 3 --model dense
if errorlevel 1 (
  echo Training failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Convert trained XGBoost artifacts to ONNX bundle
"%PY%" snapshot_export_onnx.py --artifacts "%SCRIPT_DIR%\artifacts"
if errorlevel 1 (
  echo ONNX export failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Export policy with heuristic scales (min_conf default 0.45 recommended)
"%PY%" policy_export.py --common "%COMMON_DIR%" --model_dir "%SCRIPT_DIR%\artifacts" --min_conf 0.45
if errorlevel 1 (
  echo Policy export failed. Aborting.
  popd & endlocal & exit /b 1
)

REM Trigger EA reload
copy /y nul "%COMMON_DIR%\policy.reload" >nul 2>&1 || ( echo.>"%COMMON_DIR%\policy.reload" )

echo [OK] Training + export complete. policy.json written and reload signaled.
popd
endlocal
