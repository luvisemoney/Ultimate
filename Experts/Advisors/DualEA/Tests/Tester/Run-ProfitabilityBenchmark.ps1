param([string]$Symbols='USDCHF,EURUSD,USDJPY,XAUUSD,US500,WTI,BTCUSD,ETHUSD',[switch]$Resume,[ValidateSet(0,4)][int]$TickModel=4)
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'model-evidence'
$results=@()
$binary=Join-Path $PSScriptRoot '..\Benchmark_UniversalONNX.ex5'
$binaryHash=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
$resultsPath=Join-Path $out $(if($TickModel -eq 4){'profitability-benchmark-results.json'}else{'profitability-generated-results.json'})
if($Resume -and (Test-Path -LiteralPath $resultsPath)){$results=@(Get-Content -LiteralPath $resultsPath -Raw|ConvertFrom-Json|ForEach-Object {$_})}
foreach($symbol in $Symbols.Split(',')){
 $case=$(if($TickModel -eq 4){'onnx_execution_'}else{'onnx_generated_'})+$symbol.ToLowerInvariant()
 if($Resume -and ($results|Where-Object {$_.symbol -eq $symbol -and $_.benchmark_sha256 -eq $binaryHash})){continue}
 try{
  & (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case $case -Expert Tests\Benchmark_UniversalONNX -Symbol $symbol -From 2026.10.01 -To 2026.10.28 -TickModel $TickModel -TimeoutSeconds 600 -Artifacts @('benchmark-deals.csv')
 }catch{
  $failedLog=Join-Path $out ($case+'-agent.log')
  if(!(Test-Path -LiteralPath $failedLog) -or (Get-Item -LiteralPath $failedLog).Length -ne 0){throw}
  Write-Output ('Retrying empty tester startup once: '+$symbol)
  & (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case $case -Expert Tests\Benchmark_UniversalONNX -Symbol $symbol -From 2026.10.01 -To 2026.10.28 -TickModel $TickModel -TimeoutSeconds 600 -Artifacts @('benchmark-deals.csv')
 }
 $raw=Get-Content -LiteralPath (Join-Path $out ($case+'-agent.log')) -Raw
 $match=[regex]::Match($raw,'\[BENCHMARK RESULT\] (\{[^\r\n]+\})')
 if(!$match.Success){throw ('Missing benchmark result: '+$symbol)}
 $r=$match.Groups[1].Value|ConvertFrom-Json
 if($r.decisions -lt 1 -or $r.entry_requests -lt 1 -or $r.entries_filled -lt 1 -or $r.trades -lt 1){throw ('No execution evidence: '+$symbol)}
 if($r.inference_failures -gt 0 -or $r.cost_failures -gt 0){throw ('Inference or accounting errors require review: '+$symbol)}
 if([Math]::Abs($r.net_profit-$r.deal_ledger_net) -gt 0.05){throw ('Deal ledger does not reconcile: '+$symbol)}
 if($TickModel -eq 4 -and $raw -notmatch 'generating based on real ticks'){throw ('Real-tick mode not verified: '+$symbol)}
 $r|Add-Member -NotePropertyName case -NotePropertyValue $case
 $r|Add-Member -NotePropertyName tester_model -NotePropertyValue $(if($TickModel -eq 4){'real_ticks_requested'}else{'generated_every_tick'})
 $r|Add-Member -NotePropertyName benchmark_sha256 -NotePropertyValue $binaryHash
 $r|Add-Member -NotePropertyName tick_data_warnings -NotePropertyValue @([regex]::Matches($raw,'[^\r\n]*(?:real ticks absent|real ticks discarded|ticks missing|no real ticks|real ticks.*generated)[^\r\n]*')|ForEach-Object {$_.Value})
 $results=@($results|Where-Object {$_.symbol -ne $symbol})+@($r)
 $results|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $resultsPath -Encoding UTF8
 Write-Output ('EXECUTION VERIFIED '+$symbol+' fills='+$r.entries_filled+' net='+$r.net_profit+' after_stress='+$r.net_after_stress_costs)
}
