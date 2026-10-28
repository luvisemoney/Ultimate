$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot '..\Test_NewsPublisher.ps1')
foreach($case in @(@('news_sentiment_contract','Test_NewsSentiment'),@('regime_indicators_contract','Test_RegimeIndicators'),@('tick_latency_contract','Test_TickLatency'))){
 & (Join-Path $PSScriptRoot 'Run-ModelTask.ps1') -Case $case[0] -Expert ('Tests\'+$case[1]) -From 2026.10.05 -To 2026.10.06 -TimeoutSeconds 180
}
& (Join-Path $PSScriptRoot '..\..\ML\Test-UniversalModel.ps1')
