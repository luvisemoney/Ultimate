param([string]$BrowserPath='',[int]$Port=9225,[switch]$Interactive)
$ErrorActionPreference='Stop'
try{
 $version=Invoke-RestMethod ('http://127.0.0.1:'+$Port+'/json/version') -TimeoutSec 1
 if($version.Browser){Write-Output 'Collector browser is already running';return}
}catch{}
if(!$BrowserPath){
 $BrowserPath=@('C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe','C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe','C:\Program Files\Google\Chrome\Application\chrome.exe')|Where-Object {Test-Path -LiteralPath $_}|Select-Object -First 1
}
if(!$BrowserPath){throw 'Install a Chromium browser on this Windows machine or supply -BrowserPath'}
$profile=Join-Path $PSScriptRoot 'artifacts\forexfactory\browser-profile'
New-Item -ItemType Directory -Path $profile -Force|Out-Null
$args=@('--no-first-run','--remote-debugging-address=127.0.0.1',('--remote-debugging-port='+$Port),('--user-data-dir="'+$profile+'"'),'https://www.forexfactory.com/news')
$style=if($Interactive){'Normal'}else{'Hidden'}
$p=Start-Process -FilePath $BrowserPath -ArgumentList $args -WindowStyle $style -PassThru
[ordered]@{pid=$p.Id;port=$Port;profile=$profile;browser=$BrowserPath;started_utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path (Split-Path $profile) 'browser.json') -Encoding UTF8
Write-Output ('Collector browser started; PID='+$p.Id+'; manual site verification may be required')
