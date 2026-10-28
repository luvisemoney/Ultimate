$ErrorActionPreference='Stop'
$lockPath=Join-Path $env:TEMP 'DualEA-GitHubSync.lock'
try{$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Write-Output 'Another sync is running';exit 0}
try{
 & (Join-Path $PSScriptRoot 'Export-DashboardSnapshot.ps1')
 & (Join-Path $PSScriptRoot 'Sync-GitHubRepository.ps1') -Push
}finally{$lock.Dispose()}
