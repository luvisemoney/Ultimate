param(
 [string]$Config=(Join-Path $PSScriptRoot 'news_sources.json'),
 [string]$OutputFile=(Join-Path $PSScriptRoot 'artifacts\news\news_sentiment.tsv')
)
$ErrorActionPreference='Stop'
$sources=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
$cache=Join-Path $PSScriptRoot 'artifacts\news\sources'
New-Item -ItemType Directory -Path $cache -Force|Out-Null
$rows=New-Object 'Collections.Generic.List[string]'
$rows.Add("id`tobserved_utc`tpublished_utc`texpires_utc`ttarget`tscore`timpact`turl`theadline`tmethod")
$seen=New-Object 'Collections.Generic.HashSet[string]'
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$status=@()
foreach($source in $sources){
 if($source.name -notmatch '^[a-z0-9_-]+$'){throw 'Invalid source cache name'}
 $file=Join-Path $cache ($source.name+'.tsv')
 try{
  & (Join-Path $PSScriptRoot 'Update-NewsSentiment.ps1') -FeedUrl $source.url -Target $source.target -OutputFile $file
  $status+=[pscustomobject]@{source=$source.name;fetch='OK'}
 }catch{
  Write-Warning ('Source unavailable; using unexpired cached context: '+$source.name)
  $status+=[pscustomobject]@{source=$source.name;fetch='FAILED';error=$_.Exception.Message}
 }
 if(Test-Path -LiteralPath $file){
  foreach($line in ([IO.File]::ReadAllLines($file)|Select-Object -Skip 1)){
   $fields=$line.Split("`t")
   if($fields.Count -eq 10 -and [long]$fields[3] -gt $now -and $seen.Add($fields[0]+'|'+$fields[4])){$rows.Add($line)}
  }
 }
}
$forexFactory=Join-Path $PSScriptRoot 'artifacts\forexfactory\news_sentiment.tsv'
if(Test-Path -LiteralPath $forexFactory){
 $ffRows=0
 foreach($line in ([IO.File]::ReadAllLines($forexFactory)|Select-Object -Skip 1)){
  $fields=$line.Split("`t")
  if($fields.Count -eq 10 -and [long]$fields[1] -le $now -and [long]$fields[3] -gt $now -and $seen.Add($fields[0]+'|'+$fields[4])){$rows.Add($line);$ffRows++}
 }
 $status+=[pscustomobject]@{source='forex_factory_browser';fetch='CACHED';rows=$ffRows}
}
if(($status|Where-Object {$_.fetch -eq 'OK'}|Measure-Object).Count -eq 0 -and $rows.Count -eq 1){throw 'All sources unavailable and no fresh cache; previous bundle preserved'}
$dest=[IO.Path]::GetFullPath($OutputFile)
New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null
$temp=$dest+'.tmp-'+[guid]::NewGuid().ToString('N')
try{
 [IO.File]::WriteAllLines($temp,$rows,(New-Object Text.UTF8Encoding($false)))
 if(Test-Path -LiteralPath $dest){[IO.File]::Replace($temp,$dest,($dest+'.previous'))}else{[IO.File]::Move($temp,$dest)}
}finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}}
[pscustomobject]@{observed_utc=[DateTime]::UtcNow.ToString('o');rows=$rows.Count-1;sources=$status;calibrated=$false}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ($dest+'.status.json') -Encoding UTF8
Write-Output ('NEWS BUNDLE rows='+($rows.Count-1)+' output='+$dest)
