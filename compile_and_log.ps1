# PowerShell script to compile and log output
$logFile = "$PSScriptRoot\compile_output.txt"
$eaPath = "$PSScriptRoot\Experts\OTC_Escape_Learning.mq5"
$compiler = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"

# Start the compilation process and capture output
& "$compiler" /compile:"$eaPath" /log:"$logFile"

# Display the log file content
if (Test-Path $logFile) {
    Write-Host "=== Compilation Log ==="
    Get-Content $logFile
} else {
    Write-Host "Error: Compilation log file not found."
}
