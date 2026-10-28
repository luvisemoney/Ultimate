param([string]$Symbols='')
$ErrorActionPreference='Stop'
$dualRoot=Split-Path $PSScriptRoot
$tester=Join-Path $dualRoot 'Tests\Tester'
$bundle=Join-Path $PSScriptRoot 'artifacts\universal'
$verification=Get-Content -LiteralPath (Join-Path $bundle 'verification.json') -Raw | ConvertFrom-Json
$metadata=Get-Content -LiteralPath (Join-Path $bundle 'onnx_config.json') -Raw | ConvertFrom-Json
if(!$Symbols){
 $preferred=@('USDCHF','EURUSD','USDJPY','XAUUSD','US500','WTI','BTCUSD','ETHUSD')
 $chosen=@($preferred|Where-Object {$metadata.supported_symbols -contains $_})
 if($chosen.Count -eq 0){$chosen=@($metadata.supported_symbols|Select-Object -First 8)}
 $Symbols=$chosen -join ','
}
$unsupported=@('EURCAD','EURCHF','AUDCAD','NZDCAD','GBPCHF','CHFJPY','USDSEK','USDNOK','AAPL.OQ','MSFT.OQ')|Where-Object {$metadata.supported_symbols -notcontains $_}|Select-Object -First 1
if(!$unsupported){throw 'Choose an untrained known broker symbol for the rejection test.'}
$stage=Join-Path $tester 'runtime\MQL5\Files\DualEA'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach($file in @('signal_model.onnx','onnx_config.ini','onnx_config.json')){Copy-Item -LiteralPath (Join-Path $bundle $file) -Destination $stage -Force}
$results=@()
foreach($symbol in $Symbols.Split(',')){
 if($metadata.supported_symbols -notcontains $symbol){throw ('Unsupported requested test symbol: '+$symbol)}
 $case='model_'+$symbol.ToLowerInvariant()
 & (Join-Path $tester 'Run-ModelTask.ps1') -Case $case -Expert PaperEA\PaperEA_v2 -Symbol $symbol -From 2026.10.05 -To 2026.10.07 -Preset (Join-Path $tester 'universal.set') -TimeoutSeconds 180
 $log=Join-Path $tester ('model-evidence\'+$case+'-agent.log')
 $raw=Get-Content -LiteralPath $log -Raw
 if($raw -notmatch ('ONNX predictor ready \('+[regex]::Escape([string]$metadata.onnx_model.feature_count)+' features\)') -or $raw -match '\[MODEL-REQUIRED\]|\[MODEL-CONTRACT\]|Unable to build ML predictor') {throw ('Universal model integration failed: '+$symbol)}
 if($raw -match 'SYSTEM MONITOR CIRCUIT BREAKER TRIGGERED:[^\r\n]*TickLatency'){throw ('TickLatency circuit breaker during normal tester workload: '+$symbol)}
 $tickSamples=[regex]::Matches($raw,'TickWork: ([0-9.]+)ms')
 if($tickSamples.Count -lt 1){throw ('Completed tick-work telemetry missing: '+$symbol)}
 $sla=[regex]::Match($raw,'\[TICK-SLA\] samples=(\d+) max_work_ms=([0-9.]+) max_handler_ms=([0-9.]+) warning_exceedances=(\d+) critical_exceedances=(\d+)')
 if(!$sla.Success -or [long]$sla.Groups[1].Value -lt 1){throw ('Individual handler telemetry missing: '+$symbol)}
 if([double]$sla.Groups[3].Value -gt 50 -or [long]$sla.Groups[5].Value -gt 0){throw ('Individual handler exceeded 50ms: '+$symbol)}
 $orders=[regex]::Matches($raw,'OrderSend: type=[^\r\n]*').Count
 $predictions=[regex]::Matches($raw,'\[MODEL-CLASSIFY\][^\r\n]*').Count
 if($predictions -lt 1){throw ('No actual universal classification emitted: '+$symbol)}
 $balance=[regex]::Match($raw,'final balance ([0-9.]+) USD').Groups[1].Value
 $results+=[pscustomobject]@{symbol=$symbol;status='PASS';model_sha256=$verification.model_sha256;predictions=$predictions;entry_requests=$orders;final_balance_usd=$balance;handler_samples=[long]$sla.Groups[1].Value;max_work_ms=[double]$sla.Groups[2].Value;max_handler_ms=[double]$sla.Groups[3].Value;warning_exceedances=[long]$sla.Groups[4].Value;critical_exceedances=[long]$sla.Groups[5].Value;live_feed_guarantee='UNVERIFIED';log=[IO.Path]::GetFileName($log)}
 Write-Output ('UNIVERSAL EA PASS '+$symbol+' predictions='+$predictions+' entries='+$orders+' balance='+$balance)
 [IO.File]::WriteAllText((Join-Path $tester 'model-evidence\integration-results.json'),($results|ConvertTo-Json -Depth 4))
}
& (Join-Path $tester 'Run-ModelTask.ps1') -Case unsupported_symbol -Expert PaperEA\PaperEA_v2 -Symbol $unsupported -From 2026.10.05 -To 2026.10.06 -Preset (Join-Path $tester 'universal.set') -ExpectedFailureTag MODEL-CONTRACT -TimeoutSeconds 180
& (Join-Path $tester 'Run-ModelTask.ps1') -Case unsupported_timeframe -Expert PaperEA\PaperEA_v2 -Symbol ([string]$metadata.supported_symbols[0]) -Period M15 -From 2026.10.05 -To 2026.10.06 -Preset (Join-Path $tester 'universal.set') -ExpectedFailureTag MODEL-CONTRACT -TimeoutSeconds 180
$rejections=@{unsupported_symbol='PASS';unsupported_timeframe='PASS';model_sha256=$verification.model_sha256}
[IO.File]::WriteAllText((Join-Path $tester 'model-evidence\contract-rejections.json'),($rejections|ConvertTo-Json))
$eaPath=Join-Path $dualRoot 'PaperEA\PaperEA_v2.ex5'
$eaHash=(Get-FileHash -LiteralPath $eaPath -Algorithm SHA256).Hash.ToLowerInvariant()
$runtimeEA=Join-Path $tester 'runtime\MQL5\Experts\Advisors\DualEA\PaperEA\PaperEA_v2.ex5'
if($eaHash -ne (Get-FileHash -LiteralPath $runtimeEA -Algorithm SHA256).Hash.ToLowerInvariant()){throw 'Tested EA executable mismatch'}
$proof=[ordered]@{status='PASS';model_sha256=$verification.model_sha256;ea_sha256=$eaHash;tested_symbols=@($results|ForEach-Object {$_.symbol});classification_events=($results|Measure-Object -Property predictions -Sum).Sum;unsupported_symbol='PASS';unsupported_timeframe='PASS';test_from='2026.10.05';test_to='2026.10.07';model='M1 OHLC';simulated_entry_requests=($results|Measure-Object -Property entry_requests -Sum).Sum;verified_utc=[DateTime]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $bundle 'integration-verification.json'),($proof|ConvertTo-Json -Depth 5))
foreach($file in @('integration-results.json','contract-rejections.json')){Copy-Item -LiteralPath (Join-Path $tester ('model-evidence\'+$file)) -Destination $bundle -Force}
