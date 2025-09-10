@echo off
setlocal enabledelayedexpansion
set EXITCODE=0

REM DualEA Knowledge Base Check + Logs Tail
REM - Signals insights rebuild via Common Files flag
REM - Validates insights.json basics
REM - Tails Journal and Experts logs across all MT5 data folders
REM - Optionally syncs/executes DualEA scripts (InsightsRebuild, ValidateInsights)

REM ---- Configuration ----
set "DUALEA_COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files\DualEA"
set "FEATURES=%DUALEA_COMMON%\features.csv"
set "KBCSV=%DUALEA_COMMON%\knowledge_base.csv"
set "INSIGHTS=%DUALEA_COMMON%\insights.json"
set "TELEM_DIR=%DUALEA_COMMON%\telemetry"
set "TERMINAL_BASE=%APPDATA%\MetaQuotes\Terminal"

REM User-specified Terminal path (as requested)
if not defined MT5_TERMINAL set "MT5_TERMINAL=C:\Program Files\mt5\terminal64.exe"

REM Flags
set REBUILD=0
set RUNSCRIPT=0
set RUNVALIDATE=0
set SHOW_REPORT=0
set TAIL_LOGS=1
set TAIL_TELEMETRY=1
set FAIL_STALE=0
set FAIL_EMPTY=0
set FAIL_MISSING=0
set REQ_SYMBOLS=
set REQ_TFS=
set REQ_STRATS=

for %%F in (%*) do (
  set "ARG=%%~F"
  if /I "!ARG!"=="--rebuild-insights" set REBUILD=1
  if /I "!ARG!"=="--attempt-run-script" set RUNSCRIPT=1
  if /I "!ARG!"=="--run-validate" set RUNVALIDATE=1
  if /I "!ARG!"=="--show-report" set SHOW_REPORT=1
  if /I "!ARG!"=="--no-tail-logs" set TAIL_LOGS=0
  if /I "!ARG!"=="--no-tail-telemetry" set TAIL_TELEMETRY=0
  if /I "!ARG!"=="--fail-on-stale" set FAIL_STALE=1
  if /I "!ARG!"=="--fail-on-empty-slices" set FAIL_EMPTY=1
  if /I "!ARG!"=="--fail-on-missing-required" set FAIL_MISSING=1
  if /I "!ARG:~0,18!"=="--require-symbols=" set "REQ_SYMBOLS=!ARG:~18!"
  if /I "!ARG:~0,21!"=="--require-timeframes=" set "REQ_TFS=!ARG:~21!"
  if /I "!ARG:~0,21!"=="--require-strategies=" set "REQ_STRATS=!ARG:~21!"
  if /I "!ARG!"=="--help" goto :USAGE
  if /I "!ARG!"=="-h" goto :USAGE
)

echo(
echo ==================================================
echo        DualEA Knowledge Base Check
echo ==================================================
echo Common Files path:
for %%A in ("%DUALEA_COMMON%") do echo   %%~fA
echo Terminal executable:
echo   %MT5_TERMINAL%

if "%REBUILD%"=="1" call :SIGNAL_REBUILD

echo(
echo [1/7] Listing files and sizes
call :LIST_FILES

echo(
echo [2/7] Counting key labels in features.csv
call :COUNT_LABELS

echo(
echo [3/7] Preview last 20 lines of features.csv
call :TAIL_FILE "%FEATURES%" 20

echo(
echo [4/7] Preview last 20 lines of knowledge_base.csv
call :TAIL_FILE "%KBCSV%" 20

echo(
echo [5/7] Validate insights.json and print totals
call :VALIDATE_INSIGHTS

echo(
echo [6/7] Advanced insights validation (staleness, coverage)
call :ADVANCED_VALIDATE

echo(
echo [7/7] Tail latest Journal and Experts logs across data folders
if %TAIL_LOGS%==1 (
  call :TAIL_ALL_LOGS
) else (
  echo   Skipped (use --no-tail-logs to disable explicitly)
)

if %TAIL_TELEMETRY%==1 (
  echo(
  echo [extra] Telemetry tail (latest file)
  call :TAIL_TELEMETRY 40
)

if "%RUNSCRIPT%"=="1" call :PREP_SCRIPTS
if "%RUNSCRIPT%"=="1" call :RUN_INSIGHTS
if "%RUNVALIDATE%"=="1" call :PREP_SCRIPTS
if "%RUNVALIDATE%"=="1" call :WRITE_VALIDATE_CONFIG
if "%RUNVALIDATE%"=="1" call :RUN_VALIDATE

echo(
echo =================== DONE ========================
endlocal
exit /b %EXITCODE%

:USAGE
echo Usage: kb_check.bat [options]
echo   --rebuild-insights           Create insights.reload in Common Files (PaperEA will rebuild on next tick/timer)
echo   --attempt-run-script         Sync scripts and try to run DualEA\InsightsRebuild via terminal
echo   --run-validate               Sync and run DualEA\ValidateInsights via terminal (writes insights_validation.txt)
echo   --show-report                After validation, print insights_validation.txt if present
echo   --no-tail-logs               Do not tail Journal/Experts logs
echo   --no-tail-telemetry          Do not tail telemetry JSONL
echo   --fail-on-stale              Set nonzero exit if insights are stale
echo   --fail-on-empty-slices       Set nonzero exit if by_symbol_strategy_timeframe is empty
echo   --fail-on-missing-required   Set nonzero exit if validation reports missing required coverage
echo   --require-symbols=EURUSD,GBPUSD   Require these symbols in validation
echo   --require-timeframes=M5,M15      Require these TFs in validation
echo   --require-strategies=Foo,Bar     Require these strategies in validation
echo.
echo Environment overrides:
echo   set MT5_TERMINAL="C:\\Program Files\\mt5\\terminal64.exe"
echo.
exit /b 0

:SIGNAL_REBUILD
echo(
echo [0/7] Signaling insights rebuild via insights.reload
if not exist "%DUALEA_COMMON%" mkdir "%DUALEA_COMMON%"
type nul > "%DUALEA_COMMON%\insights.reload"
echo   created: %DUALEA_COMMON%\insights.reload
goto :eof

:LIST_FILES
if exist "%FEATURES%" (
  for %%A in ("%FEATURES%") do echo   features.csv  : %%~zA bytes
) else (
  echo   features.csv  : NOT FOUND
)
if exist "%KBCSV%" (
  for %%A in ("%KBCSV%") do echo   knowledge_base.csv : %%~zA bytes
) else (
  echo   knowledge_base.csv : NOT FOUND
)
if exist "%INSIGHTS%" (
  for %%A in ("%INSIGHTS%") do echo   insights.json : %%~zA bytes
) else (
  echo   insights.json : NOT FOUND
)
goto :eof

:COUNT_LABELS
if exist "%FEATURES%" (
  for /f %%C in ('type "%FEATURES%" ^| find /c ",r_multiple,"') do set RMULT=%%C
  for /f %%C in ('type "%FEATURES%" ^| find /c ",close_event,"') do set CEVENT=%%C
  for /f %%C in ('type "%FEATURES%" ^| find /c ",duration_sec,"') do set DURATION=%%C
  echo   r_multiple rows : !RMULT!
  echo   close_event rows: !CEVENT!
  echo   duration_sec rows: !DURATION!
) else (
  echo   features.csv missing - cannot count labels
)
goto :eof

:TAIL_FILE
set "_FILE=%~1"
set "_TAIL=%~2"
if exist "%_FILE%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail %_TAIL% -LiteralPath '%_FILE%'"
) else (
  echo   %_FILE% missing
)
goto :eof

:VALIDATE_INSIGHTS
if exist "%INSIGHTS%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try{ $j=Get-Content -Raw -LiteralPath '%INSIGHTS%' ^| ConvertFrom-Json; '  schema_version: ' + $j.schema_version; '  generated_at  : ' + $j.generated_at; if($j.totals){ '  totals:'; '    trade_count    : ' + $j.totals.trade_count; '    win_rate       : ' + $j.totals.win_rate; '    avg_R          : ' + $j.totals.avg_R; '    median_R       : ' + $j.totals.median_R; '    profit_factor  : ' + $j.totals.profit_factor; '    expectancy     : ' + $j.totals.expectancy; '    max_drawdown_R : ' + $j.totals.max_drawdown_R } else { '  totals: MISSING' } } catch { Write-Host '  ERROR: insights.json is not valid JSON'; Write-Host $_.Exception.Message; exit 2 }"
  if errorlevel 1 (
    echo   FAIL: invalid insights.json ^(JSON parse^)
    if !EXITCODE! EQU 0 set EXITCODE=2
  )
) else (
  echo   insights.json missing
)
goto :eof

:ADVANCED_VALIDATE
if exist "%INSIGHTS%" (
  for /f %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ins=Get-Item -LiteralPath ''%INSIGHTS%''; $stale=0; if(Test-Path -LiteralPath ''%FEATURES%''){ if((Get-Item -LiteralPath ''%FEATURES%'').LastWriteTime -gt $ins.LastWriteTime){$stale=1} }; if(Test-Path -LiteralPath ''%KBCSV%''){ if((Get-Item -LiteralPath ''%KBCSV%'').LastWriteTime -gt $ins.LastWriteTime){$stale=1} }; $stale"') do set STALE=%%S
  echo   stale vs sources : !STALE!
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$j=Get-Content -Raw -LiteralPath '%INSIGHTS%' ^| ConvertFrom-Json; '   by_strategy.count                 : ' + ($j.by_strategy ^| Measure-Object).Count; '   by_timeframe.count                : ' + ($j.by_timeframe ^| Measure-Object).Count; '   by_symbol_strategy_timeframe.count: ' + ($j.by_symbol_strategy_timeframe ^| Measure-Object).Count; '   uniques: symbols=' + (($j.by_symbol_strategy_timeframe.symbol ^| Sort-Object -Unique).Count) + ' strategies=' + (($j.by_symbol_strategy_timeframe.strategy ^| Sort-Object -Unique).Count) + ' timeframes=' + (($j.by_symbol_strategy_timeframe.timeframe ^| Sort-Object -Unique).Count)"
  for /f %%C in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw -LiteralPath '%INSIGHTS%' ^| ConvertFrom-Json).by_symbol_strategy_timeframe.Count"') do set CNT_SLICE=%%C
  if %SHOW_REPORT%==1 (
    if exist "%DUALEA_COMMON%\insights_validation.txt" (
      echo(
      echo --- insights_validation.txt ---
      type "%DUALEA_COMMON%\insights_validation.txt"
      echo -------------------------------
    ) else (
      echo   insights_validation.txt not found - run Scripts\ValidateInsights.mq5 to generate
    )
  )
  if %FAIL_MISSING%==1 (
    if exist "%DUALEA_COMMON%\insights_validation.txt" (
      findstr /c:"ALERT: required coverage missing" "%DUALEA_COMMON%\insights_validation.txt" >nul 2>&1
      if errorlevel 1 (
        rem no missing required
      ) else (
        echo   FAIL: required coverage missing
        if !EXITCODE! LSS 4 set EXITCODE=4
      )
    )
  )
  if %FAIL_STALE%==1 (
    if "!STALE!"=="1" (
      echo   FAIL: stale insights detected
      set EXITCODE=2
    )
  )
  if %FAIL_EMPTY%==1 (
    if "!CNT_SLICE!"=="0" (
      echo   FAIL: no slices in by_symbol_strategy_timeframe
      set EXITCODE=3
    )
  )
) else (
  echo   insights.json missing - cannot perform advanced validation
)
goto :eof

:TAIL_ALL_LOGS
echo   Scanning data folders under: %TERMINAL_BASE%
if not exist "%TERMINAL_BASE%" (
  echo   WARN: Terminal data base dir not found
  goto :eof
)
for /f "delims=" %%P in ('dir /b /ad "%TERMINAL_BASE%"') do (
  set "TERMINAL_DATA_DIR=%TERMINAL_BASE%\%%P"
  echo   --- Data Dir: !TERMINAL_DATA_DIR! ---
  call :TAIL_LOG_KIND "!TERMINAL_DATA_DIR!" "journal" "logs"
  call :TAIL_LOG_KIND "!TERMINAL_DATA_DIR!" "experts" "MQL5\Logs"
)
goto :eof

:TAIL_LOG_KIND
set "_DIR=%~1"
set "_KIND=%~2"
set "_SUB=%~3"
set "_LOGDIR=%_DIR%\%_SUB%"
if not exist "%_LOGDIR%" (
  echo     [%_KIND%] no log dir: %_LOGDIR%
  goto :eof
)
set "LASTLOG="
for /f "delims=" %%L in ('dir /b /a:-d /od "%_LOGDIR%\*.log"') do set "LASTLOG=%%L"
if not defined LASTLOG (
  echo     [%_KIND%] no *.log files in %_LOGDIR%
  goto :eof
)
echo     [%_KIND%] tail: %_LOGDIR%\%LASTLOG%
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail 40 -LiteralPath '%_LOGDIR%\%LASTLOG%'"
goto :eof

:TAIL_TELEMETRY
set "_N=%~1"
if not exist "%TELEM_DIR%" (
  echo   Telemetry dir not found: %TELEM_DIR%
  goto :eof
)
set "TLAST="
for /f "delims=" %%L in ('dir /b /a:-d /od "%TELEM_DIR%\paper*.jsonl"') do set "TLAST=%%L"
if not defined TLAST (
  echo   No telemetry files in %TELEM_DIR%
  goto :eof
)
echo   telemetry tail: %TELEM_DIR%\%TLAST%
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail %_N% -LiteralPath '%TELEM_DIR%\%TLAST%'"
goto :eof

:PREP_SCRIPTS
echo(
echo [prep] Sync Include and DualEA scripts to all data folders
if not exist "%TERMINAL_BASE%" (
  echo   WARN: Terminal data base dir not found: %TERMINAL_BASE%
  goto :eof
)
for /f "delims=" %%P in ('dir /b /ad "%TERMINAL_BASE%"') do (
  set "TERMINAL_DATA_DIR=%TERMINAL_BASE%\%%P"
  set "SCRIPTS_DIR=!TERMINAL_DATA_DIR!\MQL5\Scripts\DualEA"
  set "INCLUDE_DIR=!TERMINAL_DATA_DIR!\MQL5\Include"
  set "INCLUDE_DIR_SCRIPTS=!TERMINAL_DATA_DIR!\MQL5\Scripts\Include"
  if not exist "!SCRIPTS_DIR!" mkdir "!SCRIPTS_DIR!"
  if not exist "!INCLUDE_DIR!" mkdir "!INCLUDE_DIR!"
  if not exist "!INCLUDE_DIR_SCRIPTS!" mkdir "!INCLUDE_DIR_SCRIPTS!"
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR!" >nul
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR_SCRIPTS!" >nul
  if exist ".\Scripts\InsightsRebuild.mq5" copy /Y ".\Scripts\InsightsRebuild.mq5" "!SCRIPTS_DIR!\InsightsRebuild.mq5" >nul
  if exist ".\Scripts\ValidateInsights.mq5" copy /Y ".\Scripts\ValidateInsights.mq5" "!SCRIPTS_DIR!\ValidateInsights.mq5" >nul
)
goto :eof

:RUN_INSIGHTS
echo [run] Attempting to run insights rebuild script via terminal
if not exist "%MT5_TERMINAL%" (
  echo   WARN: Terminal not found at %MT5_TERMINAL% - skipping run
  goto :eof
)
start "MT5-Run-Insights" "%MT5_TERMINAL%" /script:"DualEA\InsightsRebuild"
echo   Launched terminal to run script ^(non-blocking^). Waiting 5 seconds...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 5" >nul 2>&1
goto :eof

:RUN_VALIDATE
echo [run] Running validation script via terminal
if not exist "%MT5_TERMINAL%" (
  echo   WARN: Terminal not found at %MT5_TERMINAL% - skipping validation run
  goto :eof
)
set "REPORT=%DUALEA_COMMON%\insights_validation.txt"
if exist "%REPORT%" del /q "%REPORT%" >nul 2>&1
start "MT5-Run-Validate" "%MT5_TERMINAL%" /script:"DualEA\ValidateInsights"
echo   Launched terminal to run script ^(non-blocking^). Waiting up to 45 seconds for report...
for /L %%I in (1,1,45) do (
  if exist "%REPORT%" goto :run_validate_done
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 1" >nul 2>&1
)
:run_validate_done
goto :eof

:WRITE_VALIDATE_CONFIG
echo(
echo [prep] Write validation requirements config
if not exist "%DUALEA_COMMON%" mkdir "%DUALEA_COMMON%"
(
  echo # DualEA validate requirements - generated by kb_check.bat
  echo RequireSymbolsCSV=%REQ_SYMBOLS%
  echo RequireTimeframesCSV=%REQ_TFS%
  echo RequireStrategiesCSV=%REQ_STRATS%
  echo FailOnMissingRequired=%FAIL_MISSING%
) > "%DUALEA_COMMON%\validate_requirements.txt"
goto :eof
