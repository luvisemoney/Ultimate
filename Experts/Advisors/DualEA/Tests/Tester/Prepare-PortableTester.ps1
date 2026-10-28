param(
    [string]$Installation = 'C:\Program Files\MetaTrader 5',
    [string]$Server = 'FXCC1-Trade'
)
$ErrorActionPreference = 'Stop'
$expertRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$dataRoot = Split-Path (Split-Path $expertRoot)
$runtimeRoot = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
foreach ($binary in @('terminal64.exe','metatester64.exe')) {
    Copy-Item -LiteralPath (Join-Path $Installation $binary) -Destination (Join-Path $runtimeRoot $binary) -Force
}
$runtimeConfig = Join-Path $runtimeRoot 'Config'
New-Item -ItemType Directory -Path $runtimeConfig -Force | Out-Null
$servers = Join-Path $dataRoot 'config\servers.dat'
if (Test-Path -LiteralPath $servers) {
    Copy-Item -LiteralPath $servers -Destination $runtimeConfig -Force
}
# No accounts.dat, passwords, charts, active profile, or trading settings are copied.
$serverRoot = Join-Path $dataRoot ('bases\' + $Server)
$runtimeServer = Join-Path $runtimeRoot ('Bases\' + $Server)
New-Item -ItemType Directory -Path $runtimeServer -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $serverRoot 'symbols') -Destination $runtimeServer -Recurse -Force
$runtimeHistory = Join-Path $runtimeServer 'history'
New-Item -ItemType Directory -Path $runtimeHistory -Force | Out-Null
$runtimeSymbolHistory = Join-Path $runtimeHistory 'USDCHF'
New-Item -ItemType Directory -Path $runtimeSymbolHistory -Force | Out-Null
foreach ($year in @('2024.hcc','2025.hcc')) {
    Copy-Item -LiteralPath (Join-Path $serverRoot ('history\USDCHF\' + $year)) -Destination $runtimeSymbolHistory -Force
}
$runtimeExperts = Join-Path $runtimeRoot 'MQL5\Experts\Advisors\DualEA\PaperEA'
New-Item -ItemType Directory -Path $runtimeExperts -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $expertRoot 'Advisors\DualEA\PaperEA\PaperEA_v2.ex5') -Destination $runtimeExperts -Force
$runtimePresets = Join-Path $runtimeRoot 'MQL5\Profiles\Tester'
New-Item -ItemType Directory -Path $runtimePresets -Force | Out-Null
foreach ($preset in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.set' -File) {
    Copy-Item -LiteralPath $preset.FullName -Destination $runtimePresets -Force
}
$indicatorExamples = Join-Path (Split-Path $expertRoot) 'Indicators\Examples'
if (Test-Path -LiteralPath $indicatorExamples) {
    $runtimeIndicators = Join-Path $runtimeRoot 'MQL5\Indicators'
    New-Item -ItemType Directory -Path $runtimeIndicators -Force | Out-Null
    Copy-Item -LiteralPath $indicatorExamples -Destination $runtimeIndicators -Recurse -Force
}
Write-Output "Prepared isolated portable tester: $runtimeRoot"
Write-Output 'No terminal was launched. No login credentials were copied.'
Write-Output 'An authenticated data connection may still be required by MT5 before its tester can start.'
