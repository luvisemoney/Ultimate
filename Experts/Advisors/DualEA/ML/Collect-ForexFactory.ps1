param([ValidateRange(1024,65535)][int]$BrowserPort=9225,
 [string]$OutputDirectory=(Join-Path $PSScriptRoot 'artifacts\forexfactory'),
 [ValidateRange(300,3600)][int]$MinimumIntervalSeconds=300)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'BrowserCdp.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'HeadlineRules.psm1') -Force
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
function Commit-Text([string]$Name,[string]$Content){
 $path=Join-Path $OutputDirectory $Name
 $temp=$path+'.tmp-'+[guid]::NewGuid().ToString('N')
 try{[IO.File]::WriteAllText($temp,$Content,(New-Object Text.UTF8Encoding($false)));if(Test-Path -LiteralPath $path){[IO.File]::Replace($temp,$path,($path+'.previous'))}else{[IO.File]::Move($temp,$path)}}finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}}
}
$statePath=Join-Path $OutputDirectory 'collector-status.json'
if(Test-Path -LiteralPath $statePath){
 $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
 if(([DateTimeOffset]::UtcNow-[DateTimeOffset]::Parse($state.attempted_utc)).TotalSeconds -lt $MinimumIntervalSeconds){Write-Output 'FOREX FACTORY THROTTLED: previous snapshots retained';return}
}
$state=[ordered]@{attempted_utc=[DateTime]::UtcNow.ToString('o');channels=@();status='RUNNING'}
Commit-Text 'collector-status.json' ($state|ConvertTo-Json -Depth 6)
try{
 # Official calendar export is independent of the protected browser pages.
 $response=Invoke-WebRequest -Uri 'https://nfs.faireconomy.media/ff_calendar_thisweek.json' -UseBasicParsing -TimeoutSec 20
 $calendar=$response.Content|ConvertFrom-Json
 if(@($calendar).Count -eq 0){throw 'Official calendar export was empty'}
 foreach($event in $calendar){
  $date=[DateTimeOffset]::MinValue
  if(!$event.title -or !$event.country -or ![DateTimeOffset]::TryParse($event.date,[ref]$date)){throw 'Calendar schema changed'}
 }
 Commit-Text 'calendar.json' ($calendar|ConvertTo-Json -Depth 8)
 $state.channels+=@{channel='calendar';status='OK';rows=@($calendar).Count;source='https://nfs.faireconomy.media/ff_calendar_thisweek.json'}
 $pages=Invoke-RestMethod ('http://127.0.0.1:'+$BrowserPort+'/json/list') -TimeoutSec 5
 $page=@($pages|Where-Object {$_.type -eq 'page' -and ($_.url -like 'https://www.forexfactory.com/*' -or $_.url -eq 'about:blank')})[0]
 if(!$page){throw 'Open the dedicated collector browser first'}
 Connect-Cdp $page.webSocketDebuggerUrl
 # Robots content is read without parsing or decoding hidden browser/session data.
 Invoke-Cdp Page.navigate @{url='https://www.forexfactory.com/robots.txt'}|Out-Null
 Start-Sleep -Seconds 2
 $robots=(Invoke-Cdp Runtime.evaluate @{expression='document.body.innerText';returnByValue=$true}).result.value
 if($robots -match 'Cloudflare|Vérification|Just a moment'){throw 'HUMAN_VERIFICATION_REQUIRED for robots.txt'}
 Commit-Text 'robots.txt' $robots
 # Conservative gate for this site's observed unscoped rules; unknown grouped rules stop collection.
 if($robots -match '(?im)^\s*Disallow\s*:\s*\S+' -or $robots -match '(?im)^\s*User-agent\s*:'){
  throw 'ROBOTS_REVIEW_REQUIRED: retain calendar export; review changed robots rules before browser collection'
 }
 $extractor=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'forexfactory-extract.js'))
 foreach($channel in @('news','forums','trades')){
  Invoke-Cdp Page.navigate @{url=('https://www.forexfactory.com/'+$channel)}|Out-Null
  Start-Sleep -Seconds 3
  $expression='JSON.stringify('+ $extractor.Trim() +')'
  $answer=Invoke-Cdp Runtime.evaluate @{expression=$expression;returnByValue=$true}
  if($answer.exceptionDetails){throw ('Browser extraction failed: '+$channel)}
  $payload=$answer.result.value|ConvertFrom-Json
  if($payload.status -ne 'OK'){
   $state.channels+=@{channel=$channel;status=$payload.status;rows=0}
   throw ($payload.status+': '+$channel+'; last good snapshot retained')
  }
  Commit-Text ($channel+'.json') ($payload|ConvertTo-Json -Depth 10)
  $count=if($channel -eq 'news'){@($payload.news).Count}elseif($channel -eq 'forums'){@($payload.forum).Count}else{@($payload.trade_activity).Count+@($payload.positioning).Count}
  $state.channels+=@{channel=$channel;status='OK';rows=$count;source=$payload.source_url}
  Write-Output ('FOREX FACTORY '+$channel+' rows='+$count)
 }
 # Publish only source-timestamped headlines, not forum opinions or public trades.
 $news=Get-Content -LiteralPath (Join-Path $OutputDirectory 'news.json') -Raw|ConvertFrom-Json
 $lines=New-Object 'Collections.Generic.List[string]'
 $lines.Add("id`tobserved_utc`tpublished_utc`texpires_utc`ttarget`tscore`timpact`turl`theadline`tmethod")
 $targets=[ordered]@{
  USD='\b(USD|Federal Reserve|FOMC|Fed|US dollar|U\.S\.)\b';CAD='\b(CAD|BoC|Bank of Canada|Canadian dollar)\b';
  EUR='\b(EUR|ECB|European Central Bank|euro)\b';GBP='\b(GBP|BoE|Bank of England|sterling|UK Budget)\b';
  CHF='\b(CHF|SNB|Swiss National Bank|Swiss franc)\b';JPY='\b(JPY|BoJ|Bank of Japan|yen)\b';
  AUD='\b(AUD|RBA|Reserve Bank of Australia|Australian dollar)\b';NZD='\b(NZD|RBNZ|Reserve Bank of New Zealand|Kiwi dollar)\b';
  'SYMBOL:XAUUSD'='\b(gold|XAUUSD)\b';'SYMBOL:XAGUSD'='\b(silver|XAGUSD)\b';'SYMBOL:WTI'='\bWTI\b';'SYMBOL:BRENT'='\bBrent\b'
 }
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 foreach($record in $news.news){
  $published=[long]$record.published_utc;$expires=$published+43200
  if($published -le 0 -or $published -gt $now -or $expires -le $now){continue}
  $headline=ConvertTo-PlainHeadline $record.headline
  $affectedTargets=@($targets.Keys|Where-Object {$headline -match $targets[$_]})
  foreach($target in $affectedTargets){
   $score=if($affectedTargets.Count -eq 1){Get-HeadlinePolicyScore $headline}else{0.0}
   $scoreText=([double]$score).ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)
   $lines.Add((@(('ff_news_'+$record.id),$news.observed_utc,$published,$expires,$target,$scoreText,$record.impact,$record.source_url,$headline,'headline_policy_lexicon_v1') -join "`t"))
  }
 }
 Commit-Text 'news_sentiment.tsv' (($lines.ToArray() -join "`r`n")+"`r`n")
 $state.news_context_rows=$lines.Count-1
 $state.status='OK'
}catch{
 $state.status='FAILED';$state.error=$_.Exception.Message
 throw
}finally{
 Disconnect-Cdp
 Commit-Text 'collector-status.json' ($state|ConvertTo-Json -Depth 8)
}
