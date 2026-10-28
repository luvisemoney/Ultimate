param([string]$Only='')
$ErrorActionPreference='Stop'
$runtime=(Resolve-Path (Join-Path $PSScriptRoot 'runtime')).Path
$expertRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$testsRoot=Join-Path $runtime 'MQL5\Experts\Advisors\DualEA\Tests'
$evidence=Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Path $testsRoot,$evidence -Force | Out-Null
$mainSource=Join-Path $expertRoot 'Advisors\DualEA\PaperEA\PaperEA_v2.ex5'
$mainTarget=Join-Path $runtime 'MQL5\Experts\Advisors\DualEA\PaperEA\PaperEA_v2.ex5'
Copy-Item -LiteralPath $mainSource -Destination $mainTarget -Force
$cases=@(
 @{Name='smoke'; Expert='PaperEA_v2'; Full=$true; Preset='smoke.set'},
 @{Name='csv'; Expert='Test_SQLiteCSVImport'; Result='\[CSV-TEST RESULT\]\s+failures=0'},
 @{Name='native'; Expert='Test_NativeModelPolicy'; Result='\[NATIVE-CONTRACT\]\s+RESULT checks=19 failures=0'},
 @{Name='safety'; Expert='Test_PaperExecutionSafety'; Result='\[SAFETY RESULT\]\s+checks=28 failures=0'},
 @{Name='gates'; Expert='Test_GateSafetyContract'; Result='\[GATE-SAFETY RESULT\]\s+checks=26 failures=0'},
 @{Name='logger'; Expert='Test_TradeLoggerContract'; Result='\[LOGGER-CONTRACT\]\s+RESULT.*failures=0'},
 @{Name='shadow'; Expert='PaperEA_v2'; Full=$true; Preset='shadow.set'},
 @{Name='missing_model'; Expert='PaperEA_v2'; Full=$true; Preset='missing_model.set'; ExpectedInitFailure=$true}
)
if($Only -and !($cases | Where-Object Name -eq $Only)) { throw "Unknown test case: $Only" }
$template=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'smoke.ini'))
# Resolve the local saved account identifier without persisting it in the template.
if($template -notmatch '(?im)^Login=\d+') {
 $dataRoot=Split-Path (Split-Path $expertRoot)
 $accountLine=Get-Content -LiteralPath (Join-Path $dataRoot 'config\common.ini') | Where-Object {$_ -match '^Login=\d+$'} | Select-Object -First 1
 if(!$accountLine) {throw 'MT5 needs a saved demo account before automated testing.'}
 $template=$template.Replace('[Common]',('[Common]'+[Environment]::NewLine+$accountLine))
}
$loginValue=[regex]::Match($template,'(?im)^Login=(\d+)\s*$').Groups[1].Value
function Protect-Text([string]$Value) {
 if($loginValue) { $Value=$Value.Replace($loginValue,'[REDACTED_ACCOUNT]') }
 $Value=[regex]::Replace($Value,'(?im)(password\s*[=:]\s*)[^\r\n]+','$1[REDACTED]')
 $Value=[regex]::Replace($Value,'(?i)(account\s*#?\s*|login\s*[=:]?\s*)\d{4,}','$1[REDACTED_ACCOUNT]')
 return $Value
}
function Get-AgentLogs {
 @(Get-ChildItem -LiteralPath (Join-Path $runtime 'Tester') -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue | Where-Object {$_.FullName -match '\\Agent-[^\\]+\\logs\\'})
}
function Read-AppendedLog([string]$Path,[long]$Offset) {
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  $first=$stream.ReadByte(); $second=$stream.ReadByte()
  $encoding=if($first -eq 255 -and $second -eq 254) {[Text.Encoding]::Unicode} else {[Text.Encoding]::UTF8}
  if($Offset -gt $stream.Length) {$Offset=0}
  $stream.Position=$Offset
  $bytes=New-Object byte[] ($stream.Length-$Offset)
  $read=$stream.Read($bytes,0,$bytes.Length)
  return $encoding.GetString($bytes,0,$read).TrimStart([char]0xFEFF)
 } finally {$stream.Dispose()}
}
function Rotate-TestData([string]$CaseName) {
 $candidates=@((Join-Path $runtime 'MQL5\Files\DualEA'))
 $agents=Get-ChildItem -LiteralPath (Join-Path $runtime 'Tester') -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue
 foreach($agent in $agents) {$candidates+=Join-Path $agent.FullName 'MQL5\Files\DualEA'}
 foreach($candidate in $candidates) {
  if(!(Test-Path -LiteralPath $candidate)) {continue}
  $resolved=(Resolve-Path -LiteralPath $candidate).Path
  if(!$resolved.StartsWith($runtime+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Refusing to rotate data outside portable runtime'}
  $archive=Join-Path $runtime ('archives\'+$CaseName+'-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')+'-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $archive -Force | Out-Null
  Move-Item -LiteralPath $resolved -Destination (Join-Path $archive 'DualEA')
 }
}
function Stop-TestTerminal($Process,[string]$ExpectedPath) {
 if($Process.HasExited) {return}
 $actual=Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
 if(!$actual -or ![string]::Equals($actual.Path,$ExpectedPath,[StringComparison]::OrdinalIgnoreCase)) {throw 'Process path verification failed; refusing termination'}
 $Process.CloseMainWindow() | Out-Null
 if(!$Process.WaitForExit(10000)) {
  $actual=Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
  if($actual -and [string]::Equals($actual.Path,$ExpectedPath,[StringComparison]::OrdinalIgnoreCase)) {
   Stop-Process -Id $Process.Id -Force
   $Process.WaitForExit(5000) | Out-Null
  }
 }
}
$results=@()
foreach($case in $cases) {
 if($Only -and $case.Name -ne $Only) {continue}
 if($case.Full) {Rotate-TestData $case.Name}
 $expertPath=if($case.Full) {'Advisors\DualEA\PaperEA\PaperEA_v2.ex5'} else {'Advisors\DualEA\Tests\'+$case.Expert+'.ex5'}
 if(!$case.Full) {
  $source=Join-Path $expertRoot ('Advisors\DualEA\Tests\'+$case.Expert+'.ex5')
  if(!(Test-Path -LiteralPath $source)) {throw "Compile required contract test before running: $($case.Expert)"}
  Copy-Item -LiteralPath $source -Destination $testsRoot -Force
 }
 $config=$template -replace '(?m)^Expert=.*$',('Expert='+$expertPath)
 $config=$config -replace '(?m)^Report=.*$',('Report='+$case.Name+'-report.htm')
 if($case.Name -ne 'smoke') {$config=$config -replace '(?m)^ToDate=.*$','ToDate=2025.10.02'}
 if($case.Full) {
  $config=$config -replace '(?m)^ExpertParameters=.*$',('ExpertParameters='+$case.Preset)
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $case.Preset) -Destination (Join-Path $runtime 'MQL5\Profiles\Tester') -Force
 } else {$config=$config -replace '(?m)^ExpertParameters=.*\r?\n',''}
 $configuration=Join-Path $PSScriptRoot ($case.Name+'-run.ini')
 [IO.File]::WriteAllText($configuration,$config)
 $offsets=@{}
 foreach($log in Get-AgentLogs) {$offsets[$log.FullName]=$log.Length}
 $report=Join-Path $runtime ($case.Name+'-report.htm')
 $previousReport=if(Test-Path -LiteralPath $report) {(Get-Item -LiteralPath $report).LastWriteTimeUtc} else {[DateTime]::MinValue}
 $terminalPath=Join-Path $runtime 'terminal64.exe'
 $process=Start-Process -FilePath $terminalPath -ArgumentList @('/portable',('/config:"'+$configuration+'"')) -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
 Write-Output ('Started '+$case.Name+' tester')
 $timedOut=!$process.WaitForExit(120000)
 if($timedOut) {Stop-TestTerminal $process $terminalPath}
 $raw=''
 foreach($log in Get-AgentLogs) {
  $offset=if($offsets.ContainsKey($log.FullName)) {[long]$offsets[$log.FullName]} else {0L}
  $raw+=Read-AppendedLog $log.FullName $offset
 }
 $clean=Protect-Text $raw
 [IO.File]::WriteAllText((Join-Path $evidence ($case.Name+'-agent.log')),$clean,[Text.Encoding]::UTF8)
 $issues=@()
 if($timedOut) {$issues+='Timed out after 120 seconds'}
 if($process.HasExited -and $process.ExitCode -ne 0) {$issues+='Terminal exit code '+$process.ExitCode}
 if(!$raw.Trim()) {$issues+='No newly appended agent log'}
 if($raw -match '(?i)array out of range|zero divide|division by zero|invalid pointer|invalid object pointer|critical runtime|access violation|stack overflow|unhandled exception') {$issues+='Critical runtime error in agent log'}
 if($raw -match '(?i)\[(?:CSV-TEST|NATIVE-CONTRACT|SAFETY|GATE-SAFETY|LOGGER-CONTRACT)[^\]]*FAIL|failures=[1-9]\d*') {$issues+='Contract assertion failure'}
 $orders=$raw -match '(?i)OrderSend:|REAL TRADE EXECUTED|deal #\d+.*(?:buy|sell)|market (?:buy|sell) [0-9]'
 if($case.ExpectedInitFailure) {
  if($raw -notmatch '\[MODEL-REQUIRED\]') {$issues+='Missing MODEL-REQUIRED diagnostic'}
  if($raw -notmatch '(?i)initialization failed|OnInit.*(?:non-zero|failed)|init failed') {$issues+='Expected initialization failure not observed'}
  if($orders) {$issues+='Unexpected order execution during missing-model case'}
 } else {
  if($raw -match '(?i)initialization failed|OnInit.*(?:non-zero|failed)|init failed') {$issues+='Unexpected initialization failure'}
  if($raw -notmatch '(?i)Test passed in|testing passed|OnTester result') {$issues+='No completed tester result'}
  if($case.Full -and $raw -notmatch 'Enhanced Initialization Complete') {$issues+='Full EA initialization completion missing'}
  if($case.Result -and $raw -notmatch $case.Result) {$issues+='Expected contract success marker missing'}
 }
 if($case.Name -eq 'shadow' -and $orders) {$issues+='Unexpected order execution in shadow mode'}
 $freshReport=(Test-Path -LiteralPath $report) -and (Get-Item -LiteralPath $report).LastWriteTimeUtc -gt $previousReport
 if($freshReport) {
  [IO.File]::WriteAllText((Join-Path $evidence ($case.Name+'-report.htm')),(Protect-Text ([IO.File]::ReadAllText($report))),[Text.Encoding]::UTF8)
 } elseif(!$case.ExpectedInitFailure) {$issues+='Fresh tester HTML report missing'}
 $status=if($issues.Count -eq 0) {'PASS'} else {'FAIL'}
 $result=[pscustomobject]@{Case=$case.Name;Status=$status;Issues=($issues -join '; ');OrderActivity=[bool]$orders;FreshReport=[bool]$freshReport;AgentLog=($case.Name+'-agent.log')}
 $results+=$result
 Write-Output ($case.Name+': '+$status+$(if($issues.Count) {' - '+($issues -join '; ')} else {''}))
 [IO.File]::WriteAllText((Join-Path $evidence 'results.json'),($results | ConvertTo-Json -Depth 4),[Text.Encoding]::UTF8)
 if($timedOut) {break}
}
if($results | Where-Object Status -eq 'FAIL') {exit 1}
