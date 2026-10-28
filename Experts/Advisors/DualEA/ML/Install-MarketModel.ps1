param(
 [ValidateSet('Local','Common','Both')][string]$Scope='Both',
 [string]$Bundle=(Join-Path $PSScriptRoot 'artifacts\universal')
)
$ErrorActionPreference='Stop'
$bundleRoot=(Resolve-Path -LiteralPath $Bundle).Path
$verification=Get-Content -LiteralPath (Join-Path $bundleRoot 'verification.json') -Raw | ConvertFrom-Json
$hash=(Get-FileHash -LiteralPath (Join-Path $bundleRoot 'signal_model.onnx') -Algorithm SHA256).Hash.ToLowerInvariant()
if($verification.model_sha256 -ne $hash -or $verification.native_parity -ne 'PASS' -or $verification.causal_features -ne 'PASS'){throw 'Refusing deployment of an unverified bundle'}
$audit=Get-Content -LiteralPath (Join-Path $bundleRoot 'dataset_audit.json') -Raw | ConvertFrom-Json
if($audit.status -ne 'PASS' -or $audit.model_sha256 -ne $hash){throw 'Dataset audit does not match this model'}
$metadata=Get-Content -LiteralPath (Join-Path $bundleRoot 'onnx_config.json') -Raw | ConvertFrom-Json
if($metadata.feature_contract -ne 'market_universal_v1' -or $metadata.onnx_model.sha256 -ne $hash){throw 'Bundle metadata mismatch'}
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if($Scope -in @('Common','Both')){
 $integration=Get-Content -LiteralPath (Join-Path $bundleRoot 'integration-verification.json') -Raw | ConvertFrom-Json
 $currentEA=(Get-FileHash -LiteralPath (Join-Path $expertRoot 'Advisors\DualEA\PaperEA\PaperEA_v2.ex5') -Algorithm SHA256).Hash.ToLowerInvariant()
 if($integration.model_sha256 -ne $hash -or $integration.ea_sha256 -ne $currentEA -or $integration.status -ne 'PASS'){
  throw 'Full EA integration verification does not match the model and executable.'
 }
}
$localRoot=Join-Path (Split-Path $expertRoot) 'Files\DualEA'
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\DualEA'
$destinations=@()
if($Scope -in @('Local','Both')){$destinations+=$localRoot}
if($Scope -in @('Common','Both')){$destinations+=$commonRoot}
$version='universal_h1_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'_'+$hash.Substring(0,12)
$required=@('signal_model.onnx','onnx_config.ini','onnx_config.json')
foreach($destination in $destinations){
 $resolved=[IO.Path]::GetFullPath($destination)
 if($resolved -ne [IO.Path]::GetFullPath($localRoot) -and $resolved -ne [IO.Path]::GetFullPath($commonRoot)){throw 'Unexpected deployment destination'}
 New-Item -ItemType Directory -Path $resolved -Force | Out-Null
 $versionRoot=Join-Path $resolved ('models\'+$version)
 New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
 foreach($file in @('signal_model.onnx','onnx_config.ini','onnx_config.json','metrics.json','manifest.json','verification.json','model_data.json','dataset_audit.json','integration-verification.json','integration-results.json','contract-rejections.json')){if(Test-Path -LiteralPath (Join-Path $bundleRoot $file)){Copy-Item -LiteralPath (Join-Path $bundleRoot $file) -Destination $versionRoot -Force}}
 $backup=Join-Path $versionRoot 'previous-default'
 New-Item -ItemType Directory -Path $backup -Force | Out-Null
 $existing=@{}
 foreach($file in $required){
  $target=Join-Path $resolved $file
  $existing[$file]=Test-Path -LiteralPath $target
  if($existing[$file]){Copy-Item -LiteralPath $target -Destination $backup -Force}
  Copy-Item -LiteralPath (Join-Path $versionRoot $file) -Destination ($target+'.staged-'+$version) -Force
 }
 try{
  foreach($file in $required){Move-Item -LiteralPath ((Join-Path $resolved $file)+'.staged-'+$version) -Destination (Join-Path $resolved $file) -Force}
 }catch{
  foreach($file in $required){if($existing[$file]){Copy-Item -LiteralPath (Join-Path $backup $file) -Destination (Join-Path $resolved $file) -Force}}
  throw
 }
 $installed=(Get-FileHash -LiteralPath (Join-Path $resolved 'signal_model.onnx') -Algorithm SHA256).Hash.ToLowerInvariant()
 if($installed -ne $hash){throw 'Installed model hash mismatch'}
 Write-Output ('Installed verified experimental model: '+$resolved)
}
Write-Output ('Symbols: '+($metadata.supported_symbols -join ', '))
Write-Output 'No charts were attached, restarted, or enabled for trading by this installer.'