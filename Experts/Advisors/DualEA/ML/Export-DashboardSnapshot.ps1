param([string]$OutputDirectory=(Join-Path $PSScriptRoot '..\dashboard'))
$ErrorActionPreference='Stop'
$dual=Split-Path $PSScriptRoot
$evidence=Join-Path $dual 'Tests\Tester\model-evidence'
$bundle=Join-Path $PSScriptRoot 'artifacts\universal'
$common=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\DualEA'
function Read-OptionalJson([string]$Path){if(Test-Path -LiteralPath $Path){return (Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json)};return $null}
function Select-PublicRows($Rows,[string[]]$Fields){return @($Rows|Where-Object {$null -ne $_}|Select-Object -Property $Fields)}
function Write-PublicJson([string]$Path,$Value){
 $text=$Value|ConvertTo-Json -Depth 15
 if($text -match 'gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'){throw 'Credential signature in publication data'}
 [IO.File]::WriteAllText($Path,$text,(New-Object Text.UTF8Encoding($false)))
}
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory 'data') -Force|Out-Null
$model=Read-OptionalJson (Join-Path $bundle 'verification.json')
$integration=Read-OptionalJson (Join-Path $bundle 'integration-verification.json')
$modelConfig=Read-OptionalJson (Join-Path $bundle 'onnx_config.json')
$metrics=Read-OptionalJson (Join-Path $bundle 'metrics.json')
$benchmark=Read-OptionalJson (Join-Path $evidence 'profitability-generated-results.json')
$paper=Read-OptionalJson (Join-Path $evidence 'paper-execution-results.json')
$ff=Read-OptionalJson (Join-Path $PSScriptRoot 'artifacts\forexfactory\verification.json')
$ffStatus=Read-OptionalJson (Join-Path $PSScriptRoot 'artifacts\forexfactory\collector-status.json')
$newsStatus=Read-OptionalJson (Join-Path $common 'news_sentiment.tsv.status.json')
$live=@()
foreach($dir in (Get-ChildItem (Join-Path $dual 'Tests\Tester\live-evidence') -Directory -ErrorAction SilentlyContinue|Sort-Object Name)){
 $item=Read-OptionalJson (Join-Path $dir.FullName 'live-demo-summary.json')
 if($item){$live+=Select-PublicRows @($item) @('symbol','collected_utc','complete','demo','execution_disabled','elapsed_seconds','handler_samples','p50_ms','p95_ms','p99_ms','max_handler_ms','critical_exceedances','max_timer_ms','disconnected_timer_samples','last_known_ping_min_ms','last_known_ping_max_ms','feed_delivery_latency')}
}
$news=@()
$newsFile=Join-Path $common 'news_sentiment.tsv'
if(Test-Path -LiteralPath $newsFile){
 foreach($line in ([IO.File]::ReadAllLines($newsFile)|Select-Object -Skip 1)){
  $f=$line.Split("`t");if($f.Count -ne 10){continue}
  $news+=[ordered]@{id=$f[0];observed_utc=[long]$f[1];published_utc=[long]$f[2];expires_utc=[long]$f[3];target=$f[4];rule_score=[double]::Parse($f[5],[Globalization.CultureInfo]::InvariantCulture);impact=[int]$f[6];source_url=$f[7];headline=$f[8];method=$f[9]}
 }
}
$ea=Join-Path $dual 'PaperEA\PaperEA_v2.ex5'
$eaHash=if(Test-Path -LiteralPath $ea){(Get-FileHash -LiteralPath $ea -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null}
$data=[ordered]@{
 schema_version=1;exported_utc=[DateTime]::UtcNow.ToString('o');mode='STATIC_SNAPSHOT';
 model=[ordered]@{verification=$model;integration=$integration;supported_symbols=@($modelConfig.supported_symbols);current_ea_sha256=$eaHash;tested_ea_matches=($integration -and $integration.ea_sha256 -eq $eaHash);performance_status='NOT_PROVEN_PROFITABLE'};
 benchmark=[ordered]@{strategy='Separate tester-only ONNX four-hour strategy';from='2026-10-01';to_exclusive='2026-10-28';tick_model='GENERATED_EVERY_TICK';additional_commission_per_roundturn_lot=7;additional_slippage_points_per_side=2;rows=@(Select-PublicRows $benchmark @('symbol','decisions','entry_requests','entries_filled','request_failures','trades','wins','net_profit','profit_factor','equity_drawdown_pct','commission','swap','fees','net_after_extra_commission','net_after_stress_costs','benchmark_sha256'))};
 paper=[ordered]@{strategy='Actual PaperEA with risk gates';from='2026-10-01';to_exclusive='2026-10-28';tick_model='M1_OHLC';rows=@(Select-PublicRows $paper @('symbol','trades','net_profit','profit_factor','equity_drawdown_pct','wins','generated_signals','ea_sha256'))};
 live_observations=$live;news=$news;
 forex_factory=[ordered]@{verification=$ff;collector=(Select-PublicRows @($ffStatus) @('attempted_utc','status','channels','news_context_rows'));publication_note='Forum opinions and public trade returns are collected locally, not published as labels.'};
 sources=@(Select-PublicRows $newsStatus.sources @('source','fetch','rows'));
 limitations=@('Feed-delivery latency is unmeasured.','The separate ONNX benchmark is not the full EA.','Costs include explicit sensitivity assumptions; they are not broker quotations.','Static publication does not keep MT5 running when its computer is off.')
}
$policyPath=Join-Path $common 'policy.json'
if(!(Test-Path -LiteralPath $policyPath)){throw 'No real policy exists to publish'}
$policyText=[IO.File]::ReadAllText($policyPath)
if($policyText -match '(?i)"(?:password|passwd|api_key|access_token|private_key|account_number|account_id|login)"\s*:'){throw 'Policy contains private fields; refusing public publication'}
$policy=$policyText|ConvertFrom-Json
if(!$policy.policies -and !$policy.slices){throw 'Policy has no actual policies or slices'}
$policy|Add-Member -NotePropertyName snapshot_meta -NotePropertyValue ([ordered]@{exported_utc=$data.exported_utc;source_modified_utc=(Get-Item -LiteralPath $policyPath).LastWriteTimeUtc.ToString('o');source_sha256=(Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant();execution='MT5_ONLY';probabilities='POLICY_VALUES_NOT_CALIBRATED_MODEL_PROOF'}) -Force
Write-PublicJson (Join-Path $OutputDirectory 'policy.json') $policy
Write-PublicJson (Join-Path $OutputDirectory 'data\status.json') $data
Write-Output ('DASHBOARD SNAPSHOT news='+$news.Count+' benchmark_symbols='+@($benchmark).Count+' paper_symbols='+@($paper).Count+' current_build_verified='+$data.model.tested_ea_matches)
