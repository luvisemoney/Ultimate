# CompileAndLog.ps1
# This script compiles an MQL5 EA and logs the output to a file

param (
    [string]$EAPath = "c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Advisors\escape.mq5",
    [string]$LogPath = "$PSScriptRoot\Compile_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Function to write to both console and log file
function Write-Log {
    param([string]$Message)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to console
    Write-Output $logMessage
    
    # Write to log file
    Add-Content -Path $LogPath -Value $logMessage
}

# Create log directory if it doesn't exist
$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Clear log file if it exists
if (Test-Path $LogPath) {
    Clear-Content $LogPath -Force
}

Write-Log "=== Starting EA Compilation ==="
Write-Log "EA Path: $EAPath"
Write-Log "Log File: $LogPath"

# Check if MetaEditor exists
$metaEditorPath = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
if (-not (Test-Path $metaEditorPath)) {
    Write-Log "ERROR: MetaEditor not found at $metaEditorPath"
    exit 1
}

# Get the directory of the EA
$eaDir = Split-Path -Path $EAPath -Parent
$eaFile = Split-Path -Path $EAPath -Leaf

# Change to the EA directory
Push-Location $eaDir

try {
    Write-Log "Compiling $eaFile..."
    
    # Run MetaEditor with /log parameter to get detailed output
    $process = Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:$eaFile", "/log:$LogPath" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$LogPath.stdout" -RedirectStandardError "$LogPath.stderr"
    
    # Check the exit code
    if ($process.ExitCode -eq 0) {
        Write-Log "Compilation completed successfully!"
        
        # Check if the .ex5 file was created
        $ex5File = [System.IO.Path]::ChangeExtension($EAPath, ".ex5")
        if (Test-Path $ex5File) {
            Write-Log "Output file created: $ex5File"
            $fileInfo = Get-Item $ex5File
            Write-Log "File size: $($fileInfo.Length) bytes"
            Write-Log "Last modified: $($fileInfo.LastWriteTime)"
        } else {
            Write-Log "WARNING: .ex5 file was not created"
        }
    } else {
        Write-Log "ERROR: Compilation failed with exit code $($process.ExitCode)"
        
        # Add error details if available
        if (Test-Path "$LogPath.stderr") {
            $errors = Get-Content "$LogPath.stderr" -Raw
            if ($errors) {
                Write-Log "Error details:"
                $errors -split "`r?`n" | ForEach-Object { Write-Log "  $_" }
            }
        }
        
        # Add standard output if available
        if (Test-Path "$LogPath.stdout") {
            $output = Get-Content "$LogPath.stdout" -Raw
            if ($output) {
                Write-Log "Output:"
                $output -split "`r?`n" | ForEach-Object { Write-Log "  $_" }
            }
        }
    }
    
    # Clean up temporary files
    if (Test-Path "$LogPath.stdout") { Remove-Item "$LogPath.stdout" -Force }
    if (Test-Path "$LogPath.stderr") { Remove-Item "$LogPath.stderr" -Force }
    
} catch {
    Write-Log "ERROR: An error occurred during compilation"
    Write-Log $_.Exception.Message
    Write-Log $_.ScriptStackTrace
} finally {
    Pop-Location
}

Write-Log "=== Compilation Process Completed ==="
Write-Log "Log file saved to: $LogPath"

# Open the log file in notepad
Start-Process notepad.exe -ArgumentList $LogPath -Wait
