$ErrorActionPreference='Stop'
$folder=Join-Path $PSScriptRoot '..\ML\artifacts\forexfactory'
$checks=0
function Check([bool]$Ok,[string]$Label){if(!$Ok){throw ('FOREX FACTORY FAIL: '+$Label)};$script:checks++}
$status=Get-Content -LiteralPath (Join-Path $folder 'collector-status.json') -Raw|ConvertFrom-Json
Check ($status.status -eq 'OK') 'All channels parsed successfully'
$news=Get-Content -LiteralPath (Join-Path $folder 'news.json') -Raw|ConvertFrom-Json
Check ($news.news.Count -gt 0) 'Actual headline rows'
$ids=New-Object 'Collections.Generic.HashSet[string]'
foreach($row in $news.news){
 Check ($row.published_utc -gt 0 -and $row.published_utc -le $news.observed_utc) 'Publication chronology'
 Check ($row.source_url -match '^https://www\.forexfactory\.com/news/\d+') 'Verifiable headline permalink'
 Check ($ids.Add([string]$row.id)) 'No duplicate headline IDs'
 Check ($row.impact -in @(0,1,2,3)) 'Explicit impact enum'
}
$forums=Get-Content -LiteralPath (Join-Path $folder 'forums.json') -Raw|ConvertFrom-Json
Check ($forums.forum.Count -gt 0) 'Actual forum excerpts'
foreach($row in $forums.forum){Check ($row.source_url -match '^https://www\.forexfactory\.com/thread/post/\d+' -and $row.text) 'Forum evidence link';if(!$row.published_utc){Check ($row.timestamp_precision -eq 'relative_text_only') 'Unknown exact timestamps stay unknown'}}
$trades=Get-Content -LiteralPath (Join-Path $folder 'trades.json') -Raw|ConvertFrom-Json
Check ($trades.trade_activity.Count -gt 0 -and $trades.positioning.Count -gt 0) 'Actual activity and positioning'
foreach($row in $trades.positioning){
 Check ($row.long_percent -ge 0 -and $row.long_percent -le 100 -and [Math]::Abs($row.long_percent+$row.short_percent-100) -le 1) 'Position percentages reconcile'
 $total=$row.long_traders+$row.short_traders
 Check ($total -gt 0 -and [Math]::Abs(100.0*$row.long_traders/$total-$row.long_percent) -le 1) 'Trader counts reconcile with rounded percentages'
}
$calendar=Get-Content -LiteralPath (Join-Path $folder 'calendar.json') -Raw|ConvertFrom-Json
Check ($calendar.Count -gt 0) 'Official calendar export'
$tsv=[IO.File]::ReadAllLines((Join-Path $folder 'news_sentiment.tsv'))
foreach($line in ($tsv|Select-Object -Skip 1)){
 $f=$line.Split("`t")
 Check ($f.Count -eq 10 -and [long]$f[1] -ge [long]$f[2] -and [long]$f[3] -gt [long]$f[1] -and $f[9] -eq 'headline_policy_lexicon_v1') 'EA schema and timestamps'
}
[pscustomobject]@{checks=$checks;failures=0;news_rows=$news.news.Count;forum_rows=$forums.forum.Count;activity_rows=$trades.trade_activity.Count;positioning_rows=$trades.positioning.Count;calendar_rows=$calendar.Count;ea_context_rows=$tsv.Count-1;verified_utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $folder 'verification.json') -Encoding UTF8
Write-Output ('FOREX FACTORY PASS checks='+$checks)
