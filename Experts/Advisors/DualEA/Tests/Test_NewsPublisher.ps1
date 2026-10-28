$ErrorActionPreference='Stop'
$updater=Join-Path $PSScriptRoot '..\ML\Update-NewsSentiment.ps1'
$fixture=Join-Path $PSScriptRoot 'news-publisher-fixture.xml'
$output=Join-Path $PSScriptRoot 'news-publisher-test.tsv'
$now=[DateTimeOffset]::UtcNow
$checks=0
function Check([bool]$Ok,[string]$Label){if(!$Ok){throw ('NEWS PUBLISHER FAIL: '+$Label)};$script:checks++}
function Item([string]$Id,[string]$Title,[DateTimeOffset]$Published){return '<item><title>'+[Security.SecurityElement]::Escape($Title)+'</title><link>https://example.org/'+$Id+'</link><pubDate>'+$Published.ToString('r')+'</pubDate></item>'}
try{
 $contents='<rss><channel>'+(Item 'up' 'CAD hawkish policy' $now.AddMinutes(-5))+(Item 'down' 'CAD dovish policy' $now.AddMinutes(-5))+(Item 'negated' 'Not hawkish: CAD policy' $now.AddMinutes(-5))+(Item 'up' 'Duplicate CAD hawkish policy' $now.AddMinutes(-5))+(Item 'old' 'Stale hawkish' $now.AddDays(-2))+(Item 'future' 'Future hawkish' $now.AddDays(1))+'</channel></rss>'
 [IO.File]::WriteAllText($fixture,$contents)
 & $updater -InputFile $fixture -OutputFile $output
 $rows=@([IO.File]::ReadAllLines($output)|Select-Object -Skip 1)
 Check ($rows.Count -eq 3) 'Duplicates, stale and future records excluded'
 $scores=@{};foreach($line in $rows){$f=$line.Split("`t");$scores[$f[8]]=$f[5]}
 Check ($scores['CAD hawkish policy'] -eq '1.0') 'Hawkish rule explicit'
 Check ($scores['CAD dovish policy'] -eq '-1.0') 'Dovish rule explicit'
 Check ($scores['Not hawkish: CAD policy'] -eq '0.0') 'Negation remains unscored'
 $expiry=$rows[0].Split("`t")[3]
 & $updater -InputFile $fixture -OutputFile $output
 $updated=[IO.File]::ReadAllLines($output)[1].Split("`t")
 Check ($updated[3] -eq $expiry) 'Refresh cannot make old news live longer'
 $hash=(Get-FileHash -LiteralPath $output).Hash
 [IO.File]::WriteAllText($fixture,'<rss>broken')
 $rejected=$false;try{& $updater -InputFile $fixture -OutputFile $output}catch{$rejected=$true}
 Check $rejected 'Malformed source rejected'
 Check ((Get-FileHash -LiteralPath $output).Hash -eq $hash) 'Failed parse preserves last snapshot'
 [IO.File]::WriteAllText($fixture,'<!DOCTYPE rss [<!ENTITY external SYSTEM "file:///C:/Windows/win.ini">]><rss><channel>&external;</channel></rss>')
 $rejected=$false;try{& $updater -InputFile $fixture -OutputFile $output}catch{$rejected=$true}
 Check $rejected 'External entity expansion prohibited'
 Write-Output ('NEWS PUBLISHER PASS checks='+$checks)
}finally{
 foreach($path in @($fixture,$output,($output+'.previous'),($output+'.json'))){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}}
}
