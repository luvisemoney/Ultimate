@echo off
setlocal enabledelayedexpansion
set EXITCODE=0

REM Knowledge Base Checker for DualEA (features.csv, knowledge_base.csv, insights.json)
REM Looks in the MT5 Common Files folder so it works for Tester/Live/Paper.

set DUALEA_COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files\DualEA
set FEATURES=%DUALEA_COMMON%\features.csv
set KBCSV=%DUALEA_COMMON%\knowledge_base.csv
set INSIGHTS=%DUALEA_COMMON%\insights.json

REM Parse optional flags
set REBUILD=0
set FAIL_STALE=0
set FAIL_EMPTY=0
set SHOW_REPORT=0
set BUILD=0
set RUNSCRIPT=0
set RUNVALIDATE=0
set REQ_SYMBOLS=
set REQ_TFS=
set REQ_STRATS=
set FAIL_MISSING=0
for %%F in (%*) do (
  set "ARG=%%~F"
  if /I "!ARG!"=="--rebuild-insights" set REBUILD=1
  if /I "!ARG!"=="--fail-on-stale" set FAIL_STALE=1
  if /I "!ARG!"=="--fail-on-empty-slices" set FAIL_EMPTY=1
  if /I "!ARG!"=="--show-report" set SHOW_REPORT=1
  if /I "!ARG!"=="--build-insights" set BUILD=1
  if /I "!ARG!"=="--attempt-run-script" set RUNSCRIPT=1
  if /I "!ARG!"=="--run-validate" set RUNVALIDATE=1
  if /I "!ARG:~0,18!"=="--require-symbols=" set "REQ_SYMBOLS=!ARG:~18!"
  if /I "!ARG:~0,21!"=="--require-timeframes=" set "REQ_TFS=!ARG:~21!"
  if /I "!ARG:~0,21!"=="--require-strategies=" set "REQ_STRATS=!ARG:~21!"
  if /I "!ARG!"=="--fail-on-missing-required" set FAIL_MISSING=1
)

echo(
echo ==================================================
echo        DualEA Knowledge Base Check
echo ==================================================
echo Common Files path:
for %%A in ("%DUALEA_COMMON%") do echo   %%~fA

REM Optional: Headless build via MetaEditor (compile InsightsRebuild.mq5 into Terminal Scripts)
if "%BUILD%"=="1" call :BUILD_INSIGHTS
REM Optional: Prepare and run ValidateInsights script
if "%RUNVALIDATE%"=="1" call :PREP_VALIDATE
if "%RUNVALIDATE%"=="1" call :WRITE_VALIDATE_CONFIG
if "%RUNVALIDATE%"=="1" call :RUN_VALIDATE

if %REBUILD%==1 (
  echo(
  echo [0/6] Signaling insights rebuild via insights.reload
  if not exist "%DUALEA_COMMON%" mkdir "%DUALEA_COMMON%"
  type nul > "%DUALEA_COMMON%\insights.reload"
  echo   created: %DUALEA_COMMON%\insights.reload
)

echo(
echo [1/6] Listing files and sizes
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

REM [2/5] Counting key labels in features.csv (pure CMD to avoid PS quoting issues)
echo(
echo [2/6] Counting key labels in features.csv
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

echo(
echo [3/6] Preview last 20 lines of features.csv
if exist "%FEATURES%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail 20 -LiteralPath '%FEATURES%'"
) else (
  echo   features.csv missing
)

echo(
echo [4/6] Preview last 20 lines of knowledge_base.csv
if exist "%KBCSV%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail 20 -LiteralPath '%KBCSV%'"
) else (
  echo   knowledge_base.csv missing
)

echo(
echo [5/6] Validate insights.json and print totals
if exist "%INSIGHTS%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try{ $j=Get-Content -Raw -LiteralPath '%INSIGHTS%' | ConvertFrom-Json; '  schema_version: ' + $j.schema_version; '  generated_at  : ' + $j.generated_at; if($j.totals){ '  totals:'; '    trade_count    : ' + $j.totals.trade_count; '    win_rate       : ' + $j.totals.win_rate; '    avg_R          : ' + $j.totals.avg_R; '    median_R       : ' + $j.totals.median_R; '    profit_factor  : ' + $j.totals.profit_factor; '    expectancy     : ' + $j.totals.expectancy; '    max_drawdown_R : ' + $j.totals.max_drawdown_R } else { '  totals: MISSING' } } catch { Write-Host '  ERROR: insights.json is not valid JSON'; Write-Host $_.Exception.Message; exit 2 }"
  if errorlevel 1 (
    echo   FAIL: invalid insights.json ^(JSON parse^)
    if !EXITCODE! EQU 0 set EXITCODE=2
  )
) else (
  echo   insights.json missing
)

echo(
echo [6/6] Advanced insights validation (staleness, coverage)
if exist "%INSIGHTS%" (
  rem Compute staleness (insights older than features or knowledge_base)
  for /f %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ins=Get-Item -LiteralPath ''%INSIGHTS%''; $stale=0; if(Test-Path -LiteralPath ''%FEATURES%''){ if((Get-Item -LiteralPath ''%FEATURES%'').LastWriteTime -gt $ins.LastWriteTime){$stale=1} }; if(Test-Path -LiteralPath ''%KBCSV%''){ if((Get-Item -LiteralPath ''%KBCSV%'').LastWriteTime -gt $ins.LastWriteTime){$stale=1} }; $stale"') do set STALE=%%S
  echo   stale vs sources : !STALE!
  rem Counts and uniques
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$j=Get-Content -Raw -LiteralPath '%INSIGHTS%' | ConvertFrom-Json; '   by_strategy.count                : ' + ($j.by_strategy | Measure-Object).Count; '   by_timeframe.count               : ' + ($j.by_timeframe | Measure-Object).Count; '   by_symbol_strategy_timeframe.count: ' + ($j.by_symbol_strategy_timeframe | Measure-Object).Count; '   uniques: symbols=' + (($j.by_symbol_strategy_timeframe.symbol | Sort-Object -Unique).Count) + ' strategies=' + (($j.by_symbol_strategy_timeframe.strategy | Sort-Object -Unique).Count) + ' timeframes=' + (($j.by_symbol_strategy_timeframe.timeframe | Sort-Object -Unique).Count)"
  for /f %%C in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw -LiteralPath '%INSIGHTS%' | ConvertFrom-Json).by_symbol_strategy_timeframe.Count"') do set CNT_SLICE=%%C
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$j=Get-Content -Raw -LiteralPath '%INSIGHTS%' | ConvertFrom-Json; '   uniques.symbols     : ' + (($j.by_symbol_strategy_timeframe.symbol | Sort-Object -Unique) -join ','); '   uniques.strategies  : ' + (($j.by_symbol_strategy_timeframe.strategy | Sort-Object -Unique) -join ','); '   uniques.timeframes  : ' + (($j.by_symbol_strategy_timeframe.timeframe | Sort-Object -Unique) -join ',')"
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

echo(
echo =================== DONE ========================
endlocal
exit /b %EXITCODE%

:BUILD_INSIGHTS
echo(
echo [0a] Preparing headless build: locate Terminal data directories
set "TERMINAL_BASE=%APPDATA%\MetaQuotes\Terminal"
if not exist "%TERMINAL_BASE%" (
  echo   WARN: Could not locate MetaTrader Terminal data base dir: %TERMINAL_BASE%
  goto :eof
)
echo   Using Terminal base: %TERMINAL_BASE%
for /f "delims=" %%P in ('dir /b /ad "%TERMINAL_BASE%"') do (
  set "TERMINAL_DATA_DIR=%TERMINAL_BASE%\%%P"
  echo   Target data dir: !TERMINAL_DATA_DIR!
  set "SCRIPTS_DIR=!TERMINAL_DATA_DIR!\MQL5\Scripts\DualEA"
  set "INCLUDE_DIR=!TERMINAL_DATA_DIR!\MQL5\Include"
  set "INCLUDE_DIR_SCRIPTS=!TERMINAL_DATA_DIR!\MQL5\Scripts\Include"
  if not exist "!SCRIPTS_DIR!" mkdir "!SCRIPTS_DIR!"
  if not exist "!INCLUDE_DIR!" mkdir "!INCLUDE_DIR!"
  if not exist "!INCLUDE_DIR_SCRIPTS!" mkdir "!INCLUDE_DIR_SCRIPTS!"
  echo [0b] Sync Include\* to !INCLUDE_DIR!
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR!" >nul
  echo [0b.1] Sync Include\* to !INCLUDE_DIR_SCRIPTS! - for relative ..\\Include include
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR_SCRIPTS!" >nul
  echo [0c] Copy Scripts\InsightsRebuild.mq5 to !SCRIPTS_DIR!
  copy /Y ".\Scripts\InsightsRebuild.mq5" "!SCRIPTS_DIR!\InsightsRebuild.mq5" >nul
  echo [0d] Compile InsightsRebuild.mq5 via MetaEditor (optional)
  if not defined MT5_METAEDITOR set "MT5_METAEDITOR=C:\Program Files\MetaTrader 5\MetaEditor64.exe"
  if exist "!SCRIPTS_DIR!\InsightsRebuild.mq5" if exist "%MT5_METAEDITOR%" (
    start "" /wait "%MT5_METAEDITOR%" /compile:"!SCRIPTS_DIR!\InsightsRebuild.mq5" /log >nul
  ) else (
    echo   WARN: MetaEditor not found at %MT5_METAEDITOR% (skipping compile for this dir)
  )
)
rem Prepare run regardless of ex5 (terminal will compile MQ5 if needed)
if "%RUNSCRIPT%"=="1" call :RUN_INSIGHTS
goto :eof

:PREP_VALIDATE
echo(
echo [0v] Preparing validation run: locate Terminal data directories
set "TERMINAL_BASE=%APPDATA%\MetaQuotes\Terminal"
if not exist "%TERMINAL_BASE%" (
  echo   WARN: Could not locate MetaTrader Terminal data base dir: %TERMINAL_BASE%
  goto :eof
)
echo   Using Terminal base: %TERMINAL_BASE%
for /f "delims=" %%P in ('dir /b /ad "%TERMINAL_BASE%"') do (
  set "TERMINAL_DATA_DIR=%TERMINAL_BASE%\%%P"
  echo   Target data dir: !TERMINAL_DATA_DIR!
  set "SCRIPTS_DIR=!TERMINAL_DATA_DIR!\MQL5\Scripts\DualEA"
  set "INCLUDE_DIR=!TERMINAL_DATA_DIR!\MQL5\Include"
  set "INCLUDE_DIR_SCRIPTS=!TERMINAL_DATA_DIR!\MQL5\Scripts\Include"
  if not exist "!SCRIPTS_DIR!" mkdir "!SCRIPTS_DIR!"
  if not exist "!INCLUDE_DIR!" mkdir "!INCLUDE_DIR!"
  if not exist "!INCLUDE_DIR_SCRIPTS!" mkdir "!INCLUDE_DIR_SCRIPTS!"
  echo [0v.1] Sync Include\* to !INCLUDE_DIR!
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR!" >nul
  echo [0v.2] Sync Include\* to !INCLUDE_DIR_SCRIPTS! - for relative ..\\Include include
  xcopy /E /Y /I ".\Include" "!INCLUDE_DIR_SCRIPTS!" >nul
  echo [0v.3] Copy Scripts\ValidateInsights.mq5 to !SCRIPTS_DIR!
  copy /Y ".\Scripts\ValidateInsights.mq5" "!SCRIPTS_DIR!\ValidateInsights.mq5" >nul
  echo [0v.4] Compile ValidateInsights.mq5 via MetaEditor (optional)
  if not defined MT5_METAEDITOR set "MT5_METAEDITOR=C:\Program Files\MetaTrader 5\MetaEditor64.exe"
  if exist "!SCRIPTS_DIR!\ValidateInsights.mq5" if exist "%MT5_METAEDITOR%" (
    start "" /wait "%MT5_METAEDITOR%" /compile:"!SCRIPTS_DIR!\ValidateInsights.mq5" /log >nul
  ) else (
    echo   WARN: MetaEditor not found at %MT5_METAEDITOR% (skipping compile for this dir)
  )
)
goto :eof

:RUN_INSIGHTS
echo [0e] Attempting to run script via terminal
if not defined MT5_TERMINAL set "MT5_TERMINAL=C:\Program Files\MetaTrader 5\terminal64.exe"
if not exist "%MT5_TERMINAL%" (
  echo   WARN: Terminal not found at %MT5_TERMINAL% - skipping run
  goto :eof
)
start "MT5-Run-Insights" "%MT5_TERMINAL%" /script:"DualEA\InsightsRebuild"
echo   Launched terminal to run script ^(non-blocking^). Waiting 5 seconds...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 5" >nul 2>&1
goto :eof

:RUN_VALIDATE
echo [0v.5] Running validation script via terminal
if not defined MT5_TERMINAL set "MT5_TERMINAL=C:\Program Files\MetaTrader 5\terminal64.exe"
if not exist "%MT5_TERMINAL%" (
  echo   WARN: Terminal not found at %MT5_TERMINAL% - skipping validation run
  goto :eof
)
set "REPORT=%DUALEA_COMMON%\insights_validation.txt"
rem Ensure we wait for a freshly written report (delete any stale one first)
if exist "%REPORT%" del /q "%REPORT%" >nul 2>&1
echo   Using terminal: %MT5_TERMINAL%
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
echo [0v.3b] Write validation requirements config
if not exist "%DUALEA_COMMON%" mkdir "%DUALEA_COMMON%"
(
  echo # DualEA validate requirements - generated by kb_check.bat
  echo RequireSymbolsCSV=%REQ_SYMBOLS%
  echo RequireTimeframesCSV=%REQ_TFS%
  echo RequireStrategiesCSV=%REQ_STRATS%
  echo FailOnMissingRequired=%FAIL_MISSING%
) > "%DUALEA_COMMON%\validate_requirements.txt"
goto :eof
