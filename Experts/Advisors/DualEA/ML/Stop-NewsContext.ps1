$ErrorActionPreference='Stop'
$record=Join-Path $PSScriptRoot 'artifacts\news\watcher.json'
if(!(Test-Path -LiteralPath $record)){Write-Output 'No recorded news publisher';return}
$state=Get-Content -LiteralPath $record -Raw|ConvertFrom-Json
$worker=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$state.pid)
if(!$worker){Write-Output 'News publisher has already stopped';return}
if(!$worker.CommandLine -or $worker.CommandLine.IndexOf([string]$state.script,[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'PID no longer belongs to the recorded news publisher'}
Stop-Process -Id ([int]$state.pid)
Write-Output 'News publisher stopped'
