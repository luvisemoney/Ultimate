param(
 [string]$Config=(Join-Path $PSScriptRoot 'news_sources.json'),
 [string]$OutputFile=(Join-Path $PSScriptRoot 'artifacts\news\news_sentiment.tsv'),
 [ValidateRange(60,3600)][int]$IntervalSeconds=300,
 [ValidateRange(1,1440)][int]$DurationMinutes=60,
 [switch]$ForexFactory
)
$ErrorActionPreference='Stop'
$deadline=[DateTime]::UtcNow.AddMinutes($DurationMinutes)
$ffFailures=0
$nextFF=[DateTime]::UtcNow
do{
 if($ForexFactory -and $ffFailures -lt 3 -and [DateTime]::UtcNow -ge $nextFF){
  $ffStatus=Join-Path $PSScriptRoot 'artifacts\forexfactory\collector-status.json'
  $needsHuman=$false
  if(Test-Path -LiteralPath $ffStatus){$old=Get-Content -LiteralPath $ffStatus -Raw|ConvertFrom-Json;$needsHuman=$old.status -eq 'FAILED' -and $old.error -match 'HUMAN_VERIFICATION_REQUIRED|ROBOTS_REVIEW_REQUIRED'}
  if(!$needsHuman){try{& (Join-Path $PSScriptRoot 'Collect-ForexFactory.ps1');$ffFailures=0}catch{$ffFailures++;Write-Warning $_.Exception.Message}}
  else{Write-Warning 'Forex Factory collector paused: complete the site check and run Collect-ForexFactory.ps1 manually to resume.'}
  $nextFF=[DateTime]::UtcNow.AddSeconds(300*[Math]::Pow(2,$ffFailures)+(Get-Random -Minimum 0 -Maximum 31))
 }
 try{& (Join-Path $PSScriptRoot 'Update-NewsContextBundle.ps1') -Config $Config -OutputFile $OutputFile}catch{Write-Warning $_.Exception.Message}
 $remaining=($deadline-[DateTime]::UtcNow).TotalSeconds
 if($remaining -le 0){break}
 Start-Sleep -Seconds ([int][Math]::Min($IntervalSeconds,$remaining))
}while([DateTime]::UtcNow -lt $deadline)
