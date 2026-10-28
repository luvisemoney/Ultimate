param(
 [string]$Symbols='EURUSD,GBPUSD,USDCHF,USDJPY,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,GBPJPY,XAUUSD,XAGUSD,XAUEUR,AUS200,GER40,NAS100,UK100,US30,US500,BRENT,WTI,BTCUSD,ETHUSD',
 [string]$OutputDirectory=(Join-Path $PSScriptRoot 'artifacts\universal')
)
$ErrorActionPreference='Stop'
$requested=@($Symbols.Split(',') | ForEach-Object {$_.Trim()})
if($requested.Count -lt 2 -or $requested.Count -gt 128){throw 'Choose between 2 and 128 broker symbols.'}
foreach($name in $requested){if($name -notmatch '^[A-Za-z0-9._#-]{1,32}$'){throw ('Invalid broker symbol token: '+$name)}}
if(@($requested|Sort-Object -Unique).Count -ne $requested.Count){throw 'Duplicate broker symbols.'}
$Symbols=$requested -join ','
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$tester=Join-Path (Split-Path $PSScriptRoot) 'Tests\Tester'
$runner=Join-Path $tester 'Run-ModelTask.ps1'
$includeRoot=Split-Path $expertRoot
foreach($name in @('Train_MarketModel','Test_MarketModelFeatures')) {
 $source=Join-Path (Split-Path $PSScriptRoot) ('Tests\'+$name+'.mq5')
 & 'C:\Program Files\MetaTrader 5\MetaEditor64.exe' ('/compile:'+$source) ('/log:'+$source+'.model-build.log') ('/inc:'+$includeRoot) | Out-Null
 $log=[IO.File]::ReadAllText($source+'.model-build.log')
 if($log -notmatch 'Result: 0 errors, 0 warnings') {throw ('Compile failed: '+$name)}
}
$preset=Join-Path $tester 'train_universal.set'
[IO.File]::WriteAllText($preset,('TrainingSymbols='+$Symbols+[Environment]::NewLine+'DecisionStrideBars=1||1||1||4||N'+[Environment]::NewLine))
$started=[DateTime]::UtcNow
& $runner -Case train_universal -Expert Tests\Train_MarketModel -From 2026.10.05 -To 2026.10.06 -Preset $preset -TimeoutSeconds 600
$root=Join-Path $tester 'runtime\Tester'
$data=Get-ChildItem -LiteralPath $root -Recurse -Filter 'model_data.json' -File | Where-Object {$_.LastWriteTimeUtc -ge $started -and $_.FullName -match '\\model_build\\universal_h1_logistic_v1\\'} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if(!$data){throw 'No fresh trained model artifact was produced.'}
& (Join-Path $PSScriptRoot 'Export-MarketModel.ps1') -InputDirectory $data.DirectoryName -OutputDirectory $OutputDirectory
Copy-Item -LiteralPath (Join-Path $data.DirectoryName 'dataset.csv') -Destination (Join-Path $OutputDirectory 'dataset.csv') -Force
$agentFiles=Join-Path $tester 'runtime\MQL5\Files\DualEA'
New-Item -ItemType Directory -Path $agentFiles -Force | Out-Null
foreach($name in @('signal_model.onnx','onnx_config.ini','onnx_config.json','parity_samples.csv')) {
 Copy-Item -LiteralPath (Join-Path $OutputDirectory $name) -Destination $agentFiles -Force
}
# Bind the exact tested bundle into the parity harness; tester agents clear Files.
$resources=Join-Path (Split-Path $PSScriptRoot) 'Tests\ModelResources'
New-Item -ItemType Directory -Path $resources -Force | Out-Null
foreach($name in @('signal_model.onnx','onnx_config.ini','onnx_config.json','parity_samples.csv')) {
 Copy-Item -LiteralPath (Join-Path $OutputDirectory $name) -Destination $resources -Force
}
$source=Join-Path (Split-Path $PSScriptRoot) 'Tests\Test_TrainedModelParity.mq5'
& 'C:\Program Files\MetaTrader 5\MetaEditor64.exe' ('/compile:'+$source) ('/log:'+$source+'.model-build.log') ('/inc:'+$includeRoot) | Out-Null
if([IO.File]::ReadAllText($source+'.model-build.log') -notmatch 'Result: 0 errors, 0 warnings') {throw 'Parity harness compile failed'}
& $runner -Case features -Expert Tests\Test_MarketModelFeatures -From 2026.10.05 -To 2026.10.06 -TimeoutSeconds 120
& $runner -Case trained_parity -Expert Tests\Test_TrainedModelParity -From 2026.10.05 -To 2026.10.06 -TimeoutSeconds 300
& (Join-Path $PSScriptRoot 'Audit-MarketDataset.ps1') -Bundle $OutputDirectory
& (Join-Path $PSScriptRoot 'Record-ModelVerification.ps1') -Bundle $OutputDirectory
Write-Output ('Universal model built and tested: '+$OutputDirectory)