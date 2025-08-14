param(
  [string]$RepoRoot = "$PSScriptRoot\..",
  [string]$TerminalPath = "C:\\Program Files\\MetaTrader 5\\terminal64.exe",
  [string]$MetaEditorPath = "C:\\Program Files\\MetaTrader 5\\MetaEditor64.exe",
  [string]$RequireSymbols = "",
  [string]$RequireTimeframes = "",
  [string]$RequireStrategies = "",
  [switch]$FailOnMissingRequired
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path $RepoRoot).Path

$env:MT5_TERMINAL = $TerminalPath
$env:MT5_METAEDITOR = $MetaEditorPath

$flags = @('--build-insights','--attempt-run-script','--run-validate','--fail-on-stale','--fail-on-empty-slices','--show-report')
if ($RequireSymbols)    { $flags += "--require-symbols=$RequireSymbols" }
if ($RequireTimeframes) { $flags += "--require-timeframes=$RequireTimeframes" }
if ($RequireStrategies) { $flags += "--require-strategies=$RequireStrategies" }
if ($FailOnMissingRequired.IsPresent) { $flags += "--fail-on-missing-required" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = (Join-Path $RepoRoot 'kb_check.bat')
$psi.WorkingDirectory = $RepoRoot
$psi.Arguments = ($flags -join ' ')
$psi.UseShellExecute = $false
$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit()
exit $proc.ExitCode
