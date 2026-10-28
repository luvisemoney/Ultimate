param([string]$Bundle=(Join-Path $PSScriptRoot 'artifacts\universal'))
$ErrorActionPreference='Stop'
$bundleRoot=(Resolve-Path -LiteralPath $Bundle).Path
$metadata=Get-Content -LiteralPath (Join-Path $bundleRoot 'onnx_config.json') -Raw | ConvertFrom-Json
$hash=(Get-FileHash -LiteralPath (Join-Path $bundleRoot 'signal_model.onnx') -Algorithm SHA256).Hash.ToLowerInvariant()
if($metadata.onnx_model.sha256 -ne $hash){throw 'Model hash does not match exported metadata'}
$log=Join-Path (Split-Path $PSScriptRoot) 'Tests\Tester\model-evidence\trained_parity-agent.log'
$raw=Get-Content -LiteralPath $log -Raw
if($raw -notmatch '\[MODEL-PARITY\].*failures=0' -or $raw -notmatch ('\[MODEL-PARITY HASH\]\s+'+[regex]::Escape($hash))){throw 'This exact model has not passed native parity verification'}
$features=Join-Path (Split-Path $PSScriptRoot) 'Tests\Tester\model-evidence\features-agent.log'
if((Get-Content -LiteralPath $features -Raw) -notmatch '\[MARKET-FEATURE RESULT\] checks=38 failures=0'){throw 'Shared feature regression tests have not passed'}
$audit=Get-Content -LiteralPath (Join-Path $bundleRoot 'dataset_audit.json') -Raw | ConvertFrom-Json
if($audit.status -ne 'PASS' -or $audit.model_sha256 -ne $hash){throw 'Training-data audit does not match model'}
$result=[ordered]@{model_sha256=$hash;feature_contract=$metadata.feature_contract;symbol_count=@($metadata.supported_symbols).Count;feature_count=$metadata.onnx_model.feature_count;native_parity='PASS';causal_features='PASS';dataset_audit='PASS';training_rows=$audit.split_counts[0];validation_rows=$audit.split_counts[1];test_rows=$audit.split_counts[2];verified_utc=[DateTime]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $bundleRoot 'verification.json'),($result|ConvertTo-Json -Depth 4))
Write-Output ('Exact model verified: '+$hash)