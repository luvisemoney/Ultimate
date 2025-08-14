param(
  [string]$RepoRoot = "$PSScriptRoot\..",
  [string]$TaskName = "DualEA-Insights-Validation",
  [int]$IntervalMinutes = 60,
  [switch]$RegisterOnly,
  [string]$TerminalPath = "C:\\Program Files\\MetaTrader 5\\terminal64.exe",
  [string]$MetaEditorPath = "C:\\Program Files\\MetaTrader 5\\MetaEditor64.exe",
  [string]$RequireSymbols = "",
  [string]$RequireTimeframes = "",
  [string]$RequireStrategies = "",
  [switch]$FailOnMissingRequired
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path $RepoRoot).Path
$runner = Join-Path $RepoRoot 'scripts/RunInsightsValidation.ps1'
if (-not (Test-Path $runner)) { throw "Runner not found: $runner" }

# Unregister existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Build action arguments
$argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$runner`"",'-RepoRoot',"`"$RepoRoot`"",'-TerminalPath',"`"$TerminalPath`"",'-MetaEditorPath',"`"$MetaEditorPath`"")
if ($RequireSymbols)    { $argList += @('-RequireSymbols',"`"$RequireSymbols`"") }
if ($RequireTimeframes) { $argList += @('-RequireTimeframes',"`"$RequireTimeframes`"") }
if ($RequireStrategies) { $argList += @('-RequireStrategies',"`"$RequireStrategies`"") }
if ($FailOnMissingRequired.IsPresent) { $argList += '-FailOnMissingRequired' }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ($argList -join ' ')
$start = (Get-Date).AddMinutes(2)
$trigger = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Description 'DualEA hourly insights validation'

Write-Host "Registered task '$TaskName' to run every $IntervalMinutes minutes starting at $start."
