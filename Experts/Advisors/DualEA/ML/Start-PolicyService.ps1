param([int]$Port=8000)
$ErrorActionPreference='Stop'
$stateDir=Join-Path $PSScriptRoot 'artifacts\policy-service'
New-Item -ItemType Directory -Path $stateDir -Force|Out-Null
$existing=Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if($existing){
 $health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$Port+'/health') -TimeoutSec 3
 if($health.service -ne 'DualEA.Policy'){throw 'Port is owned by a different service'}
 Write-Output 'Existing policy service is ready';return
}
$script=Join-Path $PSScriptRoot 'Serve-Policy.ps1'
$process=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script+'"'),'-Port',$Port) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $stateDir 'stdout.log') -RedirectStandardError (Join-Path $stateDir 'stderr.log') -PassThru
[ordered]@{pid=$process.Id;port=$Port;script=$script;started_utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $stateDir 'service.json') -Encoding UTF8
for($i=0;$i -lt 20;$i++){
 Start-Sleep -Milliseconds 250
 try{$health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$Port+'/health') -TimeoutSec 1;if($health.status -eq 'ready'){Write-Output ('Policy service ready; PID='+$process.Id+'; http://127.0.0.1:'+$Port+'/policy.json');return}}catch{}
 if($process.HasExited){throw 'Policy service exited; inspect policy-service logs'}
}
throw 'Policy service did not become ready; inspect policy-service logs'
