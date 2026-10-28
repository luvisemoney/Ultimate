param([string]$Bundle=(Join-Path $PSScriptRoot 'artifacts\universal'))
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'ModelDiagnostics.cs')
$model=Get-Content (Join-Path $Bundle 'model_data.json') -Raw|ConvertFrom-Json
$result=[ModelDiagnostics]::Run((Join-Path $Bundle 'dataset.csv'),[string[]]$model.supported_symbols,[double[]]$model.weights,[double[]]$model.scaler_mean,[double[]]$model.scaler_scale,[double]$model.intercept)
$saved=Get-Content (Join-Path $Bundle 'metrics.json') -Raw|ConvertFrom-Json
foreach($split in @('train','validation','test')){
 $actual=$result|Where-Object group -eq $split
 if([Math]::Abs($actual.auc-$saved.$split.auc) -gt 1e-10){throw ('Saved AUC does not reproduce: '+$split)}
}
$output=Join-Path $Bundle 'diagnostic-audit.json'
$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $output -Encoding UTF8
$result|Where-Object {$_.group -notlike 'test/day/*'}|Select-Object group,rows,auc,above55,above70,minProbability,maxProbability|Format-Table -AutoSize
Write-Output ('AUDIT PASS: saved metrics independently reproduced; '+$output)
