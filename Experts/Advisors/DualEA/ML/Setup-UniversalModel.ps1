param(
 [string]$Symbols='EURUSD,GBPUSD,USDCHF,USDJPY,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,GBPJPY,XAUUSD,XAGUSD,XAUEUR,AUS200,GER40,NAS100,UK100,US30,US500,BRENT,WTI,BTCUSD,ETHUSD'
)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'Build-MarketModel.ps1') -Symbols $Symbols
& (Join-Path $PSScriptRoot 'Install-MarketModel.ps1') -Scope Local
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$source=Join-Path (Split-Path $PSScriptRoot) 'PaperEA\PaperEA_v2.mq5'
& 'C:\Program Files\MetaTrader 5\MetaEditor64.exe' ('/compile:'+$source) ('/log:'+$source+'.universal.log') ('/inc:'+(Split-Path $expertRoot)) | Out-Null
if([IO.File]::ReadAllText($source+'.universal.log') -notmatch 'Result: 0 errors, 0 warnings'){throw 'PaperEA compilation failed'}
& (Join-Path $PSScriptRoot 'Test-UniversalModel.ps1')
& (Join-Path $PSScriptRoot 'Install-MarketModel.ps1') -Scope Common
Write-Output 'Verified universal H1 model installed. Chart attachment and order activation require an explicit user action.'