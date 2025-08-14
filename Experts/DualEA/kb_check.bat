@echo off
setlocal enabledelayedexpansion

REM Knowledge Base Checker for DualEA (features.csv, knowledge_base.csv, insights.json)
REM Looks in the MT5 Common Files folder so it works for Tester/Live/Paper.

set DUALEA_COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files\DualEA
set FEATURES=%DUALEA_COMMON%\features.csv
set KBCSV=%DUALEA_COMMON%\knowledge_base.csv
set INSIGHTS=%DUALEA_COMMON%\insights.json

echo.
echo ==================================================
echo        DualEA Knowledge Base Check
echo ==================================================
echo Common Files path:
for %%A in ("%DUALEA_COMMON%") do echo   %%~fA

echo.
echo [1/5] Listing files and sizes
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
echo.
echo [2/5] Counting key labels in features.csv
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

echo.
echo [3/5] Preview last 20 lines of features.csv
if exist "%FEATURES%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail 20 -LiteralPath '%FEATURES%'"
) else (
  echo   features.csv missing
)

echo.
echo [4/5] Preview last 20 lines of knowledge_base.csv
if exist "%KBCSV%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Tail 20 -LiteralPath '%KBCSV%'"
) else (
  echo   knowledge_base.csv missing
)

echo.
echo [5/5] Validate insights.json and print totals
if exist "%INSIGHTS%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try{ $j=Get-Content -Raw -LiteralPath '%INSIGHTS%' | ConvertFrom-Json; '  schema_version: ' + $j.schema_version; '  generated_at  : ' + $j.generated_at; if($j.totals){ '  totals:'; '    trade_count    : ' + $j.totals.trade_count; '    win_rate       : ' + $j.totals.win_rate; '    avg_R          : ' + $j.totals.avg_R; '    median_R       : ' + $j.totals.median_R; '    profit_factor  : ' + $j.totals.profit_factor; '    expectancy     : ' + $j.totals.expectancy; '    max_drawdown_R : ' + $j.totals.max_drawdown_R } else { '  totals: MISSING' } } catch { Write-Host '  ERROR: insights.json is not valid JSON'; Write-Host $_.Exception.Message; exit 2 }"
) else (
  echo   insights.json missing
)

echo.
echo =================== DONE ========================
endlocal
