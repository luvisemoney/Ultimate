param([ValidateRange(1,1440)][int]$DurationMinutes=60,[ValidateRange(60,86400)][int]$IntervalSeconds=300)
$ErrorActionPreference='Stop'
$deadline=[DateTime]::UtcNow.AddMinutes($DurationMinutes)
do {
 & (Join-Path $PSScriptRoot 'Export-DashboardSnapshot.ps1')
 & (Join-Path $PSScriptRoot 'Sync-GitHubRepository.ps1') -Push
 if([DateTime]::UtcNow -ge $deadline){break}
 Start-Sleep -Seconds $IntervalSeconds
} while([DateTime]::UtcNow -lt $deadline)
