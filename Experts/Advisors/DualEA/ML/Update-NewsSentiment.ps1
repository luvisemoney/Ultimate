param(
 [string]$FeedUrl='https://www.bankofcanada.ca/utility/news/feed/',
 [ValidatePattern('^(USD|CAD|EUR|GBP|CHF|JPY|AUD|NZD|SYMBOL:[A-Za-z0-9_.-]+)$')][string]$Target='CAD',
 [string]$InputFile='',
 [string]$OutputFile=(Join-Path $PSScriptRoot 'artifacts\news\news_sentiment.tsv'),
 [ValidateRange(1,1440)][int]$MaxAgeMinutes=720
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HeadlineRules.psm1') -Force
if($InputFile){$xmlText=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputFile))}
else{
 if(([uri]$FeedUrl).Scheme -ne 'https'){throw 'Only HTTPS feeds are supported'}
 # A blocked or failed fetch throws before touching the current snapshot.
 $response=Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 20
 $xmlText=[Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
}
$xmlText=$xmlText.TrimStart([char]0xFEFF)
$settings=New-Object Xml.XmlReaderSettings
$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit
$settings.XmlResolver=$null
$settings.MaxCharactersInDocument=2097152
$reader=[Xml.XmlReader]::Create((New-Object IO.StringReader($xmlText)),$settings)
$doc=New-Object Xml.XmlDocument
$doc.XmlResolver=$null
try{$doc.Load($reader)}finally{$reader.Dispose()}
$items=$doc.SelectNodes('//*[local-name()="item" or local-name()="entry"]')
if($items.Count -eq 0){throw 'No RSS/RDF/Atom entries found; snapshot preserved'}
$now=[DateTimeOffset]::UtcNow
$rows=New-Object 'Collections.Generic.List[string]'
$evidence=New-Object 'Collections.Generic.List[object]'
$seen=New-Object 'Collections.Generic.HashSet[string]'
$rows.Add("id`tobserved_utc`tpublished_utc`texpires_utc`ttarget`tscore`timpact`turl`theadline`tmethod")
foreach($item in $items){
 $titleNode=$item.SelectSingleNode('./*[local-name()="title"]')
 $linkNode=$item.SelectSingleNode('./*[local-name()="link" and (not(@rel) or @rel="alternate")]')
 $dateNode=$item.SelectSingleNode('./*[local-name()="pubDate" or local-name()="date" or local-name()="published"]')
 if(!$titleNode -or !$linkNode -or !$dateNode){continue}
 $title=ConvertTo-PlainHeadline $titleNode.InnerText
 $link=if($linkNode.HasAttribute('href')){$linkNode.GetAttribute('href')}else{$linkNode.InnerText.Trim()}
 $published=[DateTimeOffset]::MinValue
 if(![DateTimeOffset]::TryParse($dateNode.InnerText,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$published)){continue}
 if($published -gt $now -or ($now-$published).TotalMinutes -ge $MaxAgeMinutes -or !$title -or $link -notmatch '^https://[^\s]+$'){continue}
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$id=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($link))).Replace('-','')).ToLowerInvariant()}finally{$sha.Dispose()}
 if(!$seen.Add($id)){continue}
 $score=Get-HeadlinePolicyScore $title
 $scoreText=([double]$score).ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)
 # RSS does not supply a Forex Factory impact-folder rating. Unknown is zero.
 $rows.Add((@($id,$now.ToUnixTimeSeconds(),$published.ToUnixTimeSeconds(),$published.AddMinutes($MaxAgeMinutes).ToUnixTimeSeconds(),$Target.ToUpperInvariant(),$scoreText,0,$link,$title,'headline_policy_lexicon_v1') -join "`t"))
 $evidence.Add([pscustomobject]@{id=$id;target=$Target;published_utc=$published.ToString('o');headline=$title;source_url=$link;score=$score;method='headline_policy_lexicon_v1';impact='UNKNOWN'})
 if($evidence.Count -ge 1000){break}
}
$outputPath=[IO.Path]::GetFullPath($OutputFile)
New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force|Out-Null
$temp=$outputPath+'.tmp-'+[guid]::NewGuid().ToString('N')
try{
 [IO.File]::WriteAllLines($temp,$rows,(New-Object Text.UTF8Encoding($false)))
 if(Test-Path -LiteralPath $outputPath){[IO.File]::Replace($temp,$outputPath,($outputPath+'.previous'))}else{[IO.File]::Move($temp,$outputPath)}
}finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}}
[pscustomobject]@{observed_utc=$now.ToString('o');feed_url=$FeedUrl;input_file=$InputFile;target=$Target;rows=$evidence.Count;method='headline_policy_lexicon_v1';calibrated=$false;headlines=@($evidence.ToArray())}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ($outputPath+'.json') -Encoding UTF8
Write-Output ('HEADLINE CONTEXT rows='+$evidence.Count+' target='+$Target+' output='+$outputPath)
