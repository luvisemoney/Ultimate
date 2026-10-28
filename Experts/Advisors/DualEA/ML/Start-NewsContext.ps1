param([ValidateRange(1,1440)][int]$DurationMinutes=60,[switch]$ForexFactory)
$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'artifacts\news'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$record=Join-Path $dir 'watcher.json'
if(Test-Path -LiteralPath $record){
 $old=Get-Content -LiteralPath $record -Raw|ConvertFrom-Json
 $process=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$old.pid)
 if($process -and $process.CommandLine -and $process.CommandLine.IndexOf([string]$old.script,[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'News worker is already running; stop it with Stop-NewsContext.ps1 before changing its configuration'}
}
$script=Join-Path $PSScriptRoot 'Watch-NewsContext.ps1'
$output=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\DualEA\news_sentiment.tsv'
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script+'"'),'-OutputFile',('"'+$output+'"'),'-DurationMinutes',$DurationMinutes,'-IntervalSeconds','300')
if($ForexFactory){$args+='-ForexFactory'}
$p=Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden -RedirectStandardOutput (Join-Path $dir 'watcher-stdout.log') -RedirectStandardError (Join-Path $dir 'watcher-stderr.log') -PassThru
[ordered]@{pid=$p.Id;script=$script;forex_factory=[bool]$ForexFactory;output_file=$output;duration_minutes=$DurationMinutes;started_utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $record -Encoding UTF8
Write-Output ('News worker started; PID='+$p.Id+'; ForexFactory='+[bool]$ForexFactory)
