param(
 [Parameter(Mandatory=$true)][string]$Case,
 [Parameter(Mandatory=$true)][string]$Expert,
 [string]$Symbol='USDCHF',
 [string]$From='2026.01.05',
 [string]$To='2026.01.06',
 [string]$Preset='',
 [int]$TimeoutSeconds=600,
 [string]$Period='H1',
 [string]$ExpectedFailureTag='',
 [ValidateRange(0,4)][int]$TickModel=1,
 [string[]]$Artifacts=@()
)
$ErrorActionPreference='Stop'
$runtime=(Resolve-Path (Join-Path $PSScriptRoot 'runtime')).Path
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$dataRoot=Split-Path (Split-Path $expertRoot)
$evidence=Join-Path $PSScriptRoot 'model-evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$source=Join-Path $expertRoot ('Advisors\DualEA\'+$Expert+'.ex5')
$target=Join-Path $runtime ('MQL5\Experts\Advisors\DualEA\'+$Expert+'.ex5')
New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $target -Force
$loginLine=Get-Content -LiteralPath (Join-Path $dataRoot 'config\common.ini') | Where-Object {$_ -match '^Login=\d+$'} | Select-Object -First 1
if(!$loginLine) {throw 'A locally saved broker account is needed for tester history synchronization.'}
$login=$loginLine.Substring(6)
$accountStore=Join-Path $runtime 'Config\accounts.dat'
Copy-Item -LiteralPath (Join-Path $dataRoot 'config\accounts.dat') -Destination $accountStore -Force
$template=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'smoke.ini'))
$template=[regex]::Replace($template,'(?m)^Login=.*\r?\n','')
$template=$template.Replace('[Common]',('[Common]'+[Environment]::NewLine+$loginLine))
$template=$template -replace '(?m)^Expert=.*$',('Expert=Advisors\DualEA\'+$Expert+'.ex5')
$template=$template -replace '(?m)^Symbol=.*$',('Symbol='+$Symbol)
$template=$template -replace '(?m)^Period=.*$',('Period='+$Period)
$template=$template -replace '(?m)^Model=.*$',('Model='+$TickModel)
$template=$template -replace '(?m)^FromDate=.*$',('FromDate='+$From)
$template=$template -replace '(?m)^ToDate=.*$',('ToDate='+$To)
$template=$template -replace '(?m)^Report=.*$',('Report=model-'+$Case+'-report.htm')
if($Preset) {
 Copy-Item -LiteralPath $Preset -Destination (Join-Path $runtime 'MQL5\Profiles\Tester') -Force
 $template=$template -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+[IO.Path]::GetFileName($Preset))
} else { $template=$template -replace '(?m)^ExpertParameters=.*\r?\n','' }
$config=Join-Path $PSScriptRoot ($Case+'-run.ini')
[IO.File]::WriteAllText($config,$template)
$offsets=@{}
$logs=Get-ChildItem (Join-Path $runtime 'Tester') -Recurse -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object {$_.FullName -match '\\Agent-[^\\]+\\logs\\'}
foreach($log in $logs){$offsets[$log.FullName]=$log.Length}
$process=$null
try {
 $process=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList @('/portable',('/config:"'+$config+'"')) -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
 Write-Output ('Started model task '+$Case)
 if(!$process.WaitForExit($TimeoutSeconds*1000)) {
  $process.CloseMainWindow() | Out-Null
  if(!$process.WaitForExit(10000)) {
   $actual=Get-Process -Id $process.Id -ErrorAction SilentlyContinue
   if($actual -and $actual.Path -eq (Join-Path $runtime 'terminal64.exe')) {Stop-Process -Id $actual.Id -Force}
  }
  throw ('Model task timed out: '+$Case)
 }
 $raw=''
 $logs=Get-ChildItem (Join-Path $runtime 'Tester') -Recurse -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object {$_.FullName -match '\\Agent-[^\\]+\\logs\\'}
 foreach($log in $logs){
  $stream=[IO.File]::Open($log.FullName,'Open','Read','ReadWrite')
  try {
   $a=$stream.ReadByte();$b=$stream.ReadByte()
   $encoding=if($a -eq 255 -and $b -eq 254){[Text.Encoding]::Unicode}else{[Text.Encoding]::UTF8}
   $offset=if($offsets.ContainsKey($log.FullName)){[long]$offsets[$log.FullName]}else{0L}
   if($offset -gt $stream.Length){$offset=0}
   $stream.Position=$offset
   $bytes=New-Object byte[] ($stream.Length-$offset)
   $read=$stream.Read($bytes,0,$bytes.Length)
   $raw+=$encoding.GetString($bytes,0,$read)
  } finally {$stream.Dispose()}
 }
 [IO.File]::WriteAllText((Join-Path $evidence ($Case+'-agent.log')),$raw.Replace($login,'[REDACTED_ACCOUNT]'))
 foreach($artifact in $Artifacts){
  if([IO.Path]::GetFileName($artifact) -ne $artifact){throw 'Artifact must be a simple file name'}
  $artifactPath=Join-Path $runtime ('Tester\Agent-127.0.0.1-3000\MQL5\Files\'+$artifact)
  if(!(Test-Path -LiteralPath $artifactPath)){throw ('Missing tester artifact: '+$artifact)}
  Copy-Item -LiteralPath $artifactPath -Destination (Join-Path $evidence ($Case+'-'+$artifact)) -Force
 }
 $report=Join-Path $runtime ('model-'+$Case+'-report.htm')
 if(Test-Path -LiteralPath $report){[IO.File]::WriteAllText((Join-Path $evidence ($Case+'-report.htm')),([IO.File]::ReadAllText($report).Replace($login,'[REDACTED_ACCOUNT]')))}
 if(!$raw.Trim() -or $raw -match 'array out of range|zero divide|invalid pointer|critical runtime|failures=[1-9]'){throw ('Model task failed; inspect '+$Case+'-agent.log')}
 if($ExpectedFailureTag){
  if($raw -notmatch ('\['+[regex]::Escape($ExpectedFailureTag)+'\]') -or $raw -notmatch 'OnInit returns non-zero|initialization failed' -or $raw -match 'OrderSend:|market (buy|sell) [0-9]'){
   throw ('Expected contract rejection was not verified: '+$Case)
  }
  Write-Output ('Verified expected rejection: '+$Case)
  return
 }
 if($raw -match 'initialization failed|OnInit returns non-zero'){throw ('Unexpected initialization failure: '+$Case)}
 if($raw -notmatch 'OnTester result|Test passed in'){throw ('Model task did not finish: '+$Case)}
 Write-Output ('Completed model task '+$Case)
 foreach($line in ($raw -split '[\r\n]+')) {if($line -match '\[(?:MODEL-|MARKET-|TRAIN|PARITY)' -and $line -notmatch '\[MODEL-CLASSIFY\]'){Write-Output $line}}
} finally {
 if(Test-Path -LiteralPath $config){Remove-Item -LiteralPath $config -Force}
 if(!$process -or $process.HasExited){if(Test-Path -LiteralPath $accountStore){Remove-Item -LiteralPath $accountStore -Force}}
}
