param([string]$Symbol='USDCHF',[ValidateRange(30,86400)][int]$Seconds=180)
$ErrorActionPreference='Stop'
$runtime=(Resolve-Path (Join-Path $PSScriptRoot 'runtime')).Path
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$dataRoot=Split-Path (Split-Path $expertRoot)
$binary=Join-Path $runtime 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $binary}){throw 'Isolated terminal is already running'}
$loginLine=Get-Content -LiteralPath (Join-Path $dataRoot 'config\common.ini')|Where-Object {$_ -match '^Login=\d+$'}|Select-Object -First 1
if(!$loginLine){throw 'No locally saved account is available'}
$login=$loginLine.Substring(6)
$bundle=Join-Path $expertRoot 'Advisors\DualEA\ML\artifacts\universal'
$files=Join-Path $runtime 'MQL5\Files'
$presetDir=Join-Path $runtime 'MQL5\Presets'
New-Item -ItemType Directory -Path $presetDir,(Join-Path $files 'DualEA') -Force|Out-Null
foreach($file in @('signal_model.onnx','onnx_config.ini','onnx_config.json')){Copy-Item -LiteralPath (Join-Path $bundle $file) -Destination (Join-Path $files 'DualEA') -Force}
$newsContext=Join-Path $expertRoot 'Advisors\DualEA\ML\artifacts\news\news_sentiment.tsv'
$publishedNews=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\DualEA\news_sentiment.tsv'
if(Test-Path -LiteralPath $publishedNews){$newsContext=$publishedNews}
if(Test-Path -LiteralPath $newsContext){Copy-Item -LiteralPath $newsContext -Destination (Join-Path $files 'DualEA\news_sentiment.tsv') -Force}
$source=Join-Path $expertRoot 'Advisors\DualEA\Tests\LiveDemoLatency.ex5'
$target=Join-Path $runtime 'MQL5\Experts\Advisors\DualEA\Tests\LiveDemoLatency.ex5'
Copy-Item -LiteralPath $source -Destination $target -Force
$observerHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
$preset=Join-Path $presetDir 'live-latency.set'
@"
LiveTradingEnabled=false
ShadowMode=true
UseOnnxPredictor=true
OnnxPathsUseCommonDir=false
LoadONNXModels=false
AutoReloadModels=false
NoConstraintsMode=false
HeartbeatVerbose=false
UseNewsSentiment=true
NewsSentimentBlockOpposing=false
ObservationSeconds=$Seconds
"@|Set-Content -LiteralPath $preset -Encoding Unicode
$config=Join-Path $PSScriptRoot 'live-observe-run.ini'
@"
[Common]
$loginLine
Server=FXCC1-Trade
KeepPrivate=0
NewsEnable=0
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[StartUp]
Expert=Advisors\DualEA\Tests\LiveDemoLatency
ExpertParameters=live-latency.set
Symbol=$Symbol
Period=H1
"@|Set-Content -LiteralPath $config -Encoding Unicode
$accountStore=Join-Path $runtime 'Config\accounts.dat'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$evidence=Join-Path $PSScriptRoot ('live-evidence\'+$stamp+'-'+$Symbol)
New-Item -ItemType Directory -Path $evidence -Force|Out-Null
$summary=Join-Path $files 'live-demo-summary.json'
$csv=Join-Path $files 'live-demo-durations.csv'
foreach($path in @($summary,$csv)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}}
$offsets=@{}
foreach($folder in @('logs','MQL5\Logs')){Get-ChildItem (Join-Path $runtime $folder) -Filter '*.log' -ErrorAction SilentlyContinue|ForEach-Object {$offsets[$_.FullName]=$_.Length}}
$process=$null
try{
 Copy-Item -LiteralPath (Join-Path $dataRoot 'config\accounts.dat') -Destination $accountStore -Force
 $process=Start-Process -FilePath $binary -ArgumentList @('/portable',('/config:"'+$config+'"')) -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
 Write-Output ('Live demo observer started: '+$Symbol+' duration='+$Seconds+'s; trading disabled')
 $deadline=[DateTime]::UtcNow.AddSeconds($Seconds+150)
 while(!$process.WaitForExit(1000)){
  if([DateTime]::UtcNow -gt $deadline){throw 'Live observation timed out'}
 }
 if(!(Test-Path -LiteralPath $summary)){throw 'Observer produced no summary; inspect sanitized evidence logs'}
 Copy-Item -LiteralPath $summary,$csv -Destination $evidence -Force
 $result=Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json
 if(!$result.complete -or !$result.demo -or !$result.execution_disabled -or $result.handler_samples -lt 1){throw 'No complete safe live-demo observation was verified'}
 $result|Add-Member -NotePropertyName observer_sha256 -NotePropertyValue $observerHash
 $result|Add-Member -NotePropertyName collected_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
 $result|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $evidence 'live-demo-summary.json') -Encoding UTF8
 $result|Format-List
 Write-Output ('Evidence: '+$evidence)
}finally{
 if($process -and !$process.HasExited){$process.CloseMainWindow()|Out-Null;if(!$process.WaitForExit(10000)){Stop-Process -Id $process.Id -Force}}
 foreach($folder in @('logs','MQL5\Logs')){
  $raw=''
  foreach($log in (Get-ChildItem (Join-Path $runtime $folder) -Filter '*.log' -ErrorAction SilentlyContinue)){
   $stream=[IO.File]::Open($log.FullName,'Open','Read','ReadWrite')
   try{$a=$stream.ReadByte();$b=$stream.ReadByte();$enc=if($a -eq 255 -and $b -eq 254){[Text.Encoding]::Unicode}else{[Text.Encoding]::UTF8};$stream.Position=if($offsets.ContainsKey($log.FullName)){$offsets[$log.FullName]}else{0};$bytes=New-Object byte[] ($stream.Length-$stream.Position);$read=$stream.Read($bytes,0,$bytes.Length);$raw+=$enc.GetString($bytes,0,$read)}finally{$stream.Dispose()}
  }
  [IO.File]::WriteAllText((Join-Path $evidence ($folder.Replace('\','-')+'.log')),$raw.Replace($login,'[REDACTED_ACCOUNT]'))
 }
 foreach($path in @($config,$accountStore,$preset)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}}
}
$eaLog=[IO.File]::ReadAllText((Join-Path $evidence 'MQL5-Logs.log'))
if($eaLog -match 'array out of range|zero divide|invalid pointer|critical runtime|OrderSend:'){
 throw 'Live observer log contains a runtime fault or unexpected entry request; inspect evidence'
}
