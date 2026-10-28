$ErrorActionPreference='Stop'
$unitErrors=@()
try{& (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case adx_closed_contract -Expert Tests\Test_ADXClosedSignals -From 2026.10.01 -To 2026.10.28 -TimeoutSeconds 300}catch{$unitErrors+=$_.Exception.Message}
try{& (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case forex_factory_native -Expert Tests\Test_ForexFactoryNewsNative -From 2026.10.05 -To 2026.10.06 -TimeoutSeconds 180}catch{$unitErrors+=$_.Exception.Message}
$results=@()
foreach($symbol in @('USDCHF','EURUSD','XAUUSD')){
 $case='paper_execution_'+$symbol.ToLowerInvariant()
 & (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case $case -Expert PaperEA\PaperEA_v2 -Symbol $symbol -From 2026.10.01 -To 2026.10.28 -Preset (Join-Path $PSScriptRoot 'universal.set') -TimeoutSeconds 300
 $raw=Get-Content -LiteralPath (Join-Path $PSScriptRoot ('model-evidence\'+$case+'-agent.log')) -Raw
 $m=[regex]::Match($raw,'\[PAPER-PERFORMANCE\] trades=([0-9]+) net_profit=([-0-9.]+) gross_profit=([-0-9.]+) gross_loss=([-0-9.]+) profit_factor=([0-9.eE+-]+) equity_drawdown_pct=([0-9.]+) wins=([0-9]+)')
 if(!$m.Success){throw ('Missing actual EA performance: '+$symbol)}
 $r=[ordered]@{symbol=$symbol;trades=[int]$m.Groups[1].Value;net_profit=[double]$m.Groups[2].Value;profit_factor=[double]$m.Groups[5].Value;equity_drawdown_pct=[double]$m.Groups[6].Value;wins=[int]$m.Groups[7].Value;request_log_entries=[regex]::Matches($raw,'OrderSend:').Count;generated_signals=[regex]::Matches($raw,'Registry.GenerateSignal returned: true').Count;candidate_strategies=@([regex]::Matches($raw,'\[STRATEGY-EXPLORE\][^\r\n]*candidate=([^\r\n]+)')|ForEach-Object {$_.Groups[1].Value}|Sort-Object -Unique);gate_rejections=@([regex]::Matches($raw,'\[GATE-REJECT\][^\r\n]+')|ForEach-Object {$_.Value}|Select-Object -First 5);case=$case;model='M1_OHLC';ea_sha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot '..\..\PaperEA\PaperEA_v2.ex5') -Algorithm SHA256).Hash.ToLowerInvariant()}
 $results+=[pscustomobject]$r
 $results|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'model-evidence\paper-execution-results.json') -Encoding UTF8
 Write-Output ('ACTUAL PAPER EA '+$symbol+' trades='+$r.trades+' requests='+$r.request_log_entries+' net='+$r.net_profit)
}
if($unitErrors.Count -gt 0){throw ($unitErrors -join '; ')}
