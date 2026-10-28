param([switch]$Remove)
$ErrorActionPreference='Stop'
$name='DualEA-GitHubSourceSync'
if($Remove){Unregister-ScheduledTask -TaskName $name -Confirm:$false;return}
$script=Join-Path $PSScriptRoot 'Run-GitHubAutoSync.ps1'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$script+'"')
$periodic=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
$login=New-ScheduledTaskTrigger -AtLogOn -User $identity
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $name -Action $action -Trigger @($periodic,$login) -Principal $principal -Settings $settings -Description 'Publish reviewed MQL5 source and sanitized DualEA snapshots to luvisemoney/Ultimate; requires this computer and user session.' -Force|Out-Null
Write-Output ('Installed '+$name+' at logon and every five minutes while this user is logged on.')
