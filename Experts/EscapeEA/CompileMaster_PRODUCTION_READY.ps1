#Requires -Version 5.1
<#
.SYNOPSIS
    JAILBREAK COMPILATION SYSTEM - PRODUCTION READY
    
.DESCRIPTION
    Simplified, working PowerShell compilation system that demonstrates
    all the key security and reliability improvements from the jailbreak analysis.
    
.AUTHOR
    Red Team Architecture Panel - PRODUCTION READY
    
.VERSION
    5.1 - PRODUCTION DEPLOYMENT
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot = $PSScriptRoot,
    
    [Parameter(Mandatory=$false)]
    [switch]$ProductionOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Security constants
$DANGEROUS_CHARS = @('&', '|', ';', '$', '`', '"', "'", '<', '>', '(', ')', '{', '}')
$PRODUCTION_EA_PATTERNS = @("LiveEA_MLEnhanced.mq5", "PaperEA_MLEnhanced.mq5")
$COMPILATION_TIMEOUT = 300

# Initialize logging
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logDir = Join-Path $ProjectRoot "CompilationLogs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logDir "PRODUCTION_Compilation_$timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        default { if ($Verbose) { Write-Host $logEntry -ForegroundColor Cyan } }
    }
}

function Test-SecurityValidation {
    param([string]$Path)
    
    # Path length check
    if ($Path.Length -gt 260) {
        Write-Log "Path too long: $($Path.Length) characters" "ERROR"
        return $false
    }
    
    # Dangerous character check
    foreach ($char in $DANGEROUS_CHARS) {
        if ($Path.Contains($char)) {
            Write-Log "Dangerous character '$char' found in path" "ERROR"
            return $false
        }
    }
    
    # Path traversal check
    if ($Path.Contains("..") -or $Path.Contains("~")) {
        Write-Log "Path traversal attempt detected" "ERROR"
        return $false
    }
    
    return $true
}

function Test-MetaEditor {
    param([string]$MetaEditorPath)
    
    if (-not (Test-Path $MetaEditorPath)) {
        Write-Log "MetaEditor not found at: $MetaEditorPath" "ERROR"
        return $false
    }
    
    try {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($MetaEditorPath)
        if ($versionInfo.ProductName -notlike "*MetaEditor*") {
            Write-Log "Suspicious executable: $($versionInfo.ProductName)" "ERROR"
            return $false
        }
        
        Write-Log "MetaEditor validated: $($versionInfo.ProductName) v$($versionInfo.ProductVersion)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to validate MetaEditor: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Invoke-SecureCompilation {
    param([hashtable]$FileInfo, [bool]$Force)
    
    $fileName = $FileInfo.Name
    $filePath = $FileInfo.FullPath
    $ex5Path = $FileInfo.ExpectedEx5Path
    
    Write-Log "Compiling: $fileName"
    
    try {
        # Check if compilation needed
        if (-not $Force -and (Test-Path $ex5Path)) {
            $mq5Modified = (Get-Item $filePath).LastWriteTime
            $ex5Modified = (Get-Item $ex5Path).LastWriteTime
            
            if ($ex5Modified -gt $mq5Modified) {
                Write-Log "Skipping $fileName (up to date)"
                return @{ Status = "Skipped"; Ex5Exists = $true }
            }
        }
        
        # Clean existing .ex5 file
        if (Test-Path $ex5Path) {
            Remove-Item $ex5Path -Force
            Write-Log "Removed existing .ex5 file"
        }
        
        # Execute compilation with timeout
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $MetaEditorPath
        $processInfo.Arguments = "/compile:`"$filePath`" /log"
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        $processInfo.WorkingDirectory = $ProjectRoot
        
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        if (-not $process.WaitForExit($COMPILATION_TIMEOUT * 1000)) {
            $process.Kill()
            $stopwatch.Stop()
            Write-Log "Compilation timeout for $fileName" "ERROR"
            return @{ Status = "Failed"; Reason = "Timeout"; Ex5Exists = $false }
        }
        
        $stopwatch.Stop()
        $exitCode = $process.ExitCode
        
        # Wait for file system update
        Start-Sleep -Milliseconds 500
        
        # Verify .ex5 file creation
        $ex5Exists = Test-Path $ex5Path
        $ex5Size = if ($ex5Exists) { (Get-Item $ex5Path).Length } else { 0 }
        
        # Determine success
        $success = $ex5Exists -and $ex5Size -gt 0
        
        if ($success) {
            Write-Log "✅ $fileName compiled successfully (Size: $ex5Size bytes, Time: $($stopwatch.ElapsedMilliseconds)ms)" "SUCCESS"
            return @{ 
                Status = "Success"
                Ex5Exists = $true
                Ex5Size = $ex5Size
                CompilationTime = $stopwatch.ElapsedMilliseconds
                ExitCode = $exitCode
            }
        } else {
            $reason = if (-not $ex5Exists) { "No .ex5 file generated" } else { "Empty .ex5 file" }
            Write-Log "❌ $fileName compilation failed: $reason (Exit: $exitCode)" "ERROR"
            return @{ 
                Status = "Failed"
                Reason = $reason
                Ex5Exists = $ex5Exists
                Ex5Size = $ex5Size
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-Log "Exception during compilation of $fileName`: $($_.Exception.Message)" "ERROR"
        return @{ Status = "Exception"; Reason = $_.Exception.Message; Ex5Exists = $false }
    }
}

# Main execution
Write-Log "🔥 JAILBREAK COMPILATION SYSTEM v5.1 - PRODUCTION READY"
Write-Log "Project Root: $ProjectRoot"
Write-Log "MetaEditor: $MetaEditorPath"
Write-Log "Production Only: $ProductionOnly"

# Security validation
Write-Log "🛡️ Performing security validation..."

if (-not (Test-SecurityValidation $ProjectRoot)) {
    Write-Log "Project root security validation failed" "ERROR"
    exit 1
}

if (-not (Test-MetaEditor $MetaEditorPath)) {
    Write-Log "MetaEditor validation failed" "ERROR"
    exit 1
}

Write-Log "Security validation passed" "SUCCESS"

# Discover MQ5 files
Write-Log "🔍 Discovering MQ5 files..."
$allFiles = @()

try {
    $mq5Files = Get-ChildItem -Path $ProjectRoot -Filter "*.mq5" -Recurse -File
    
    foreach ($file in $mq5Files) {
        if (-not (Test-SecurityValidation $file.FullName)) {
            continue
        }
        
        $relativePath = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
        $isProduction = $PRODUCTION_EA_PATTERNS -contains $file.Name
        
        if ($ProductionOnly -and -not $isProduction) {
            continue
        }
        
        $fileInfo = @{
            FullPath = $file.FullName
            RelativePath = $relativePath
            Name = $file.Name
            IsProduction = $isProduction
            Size = $file.Length
            LastModified = $file.LastWriteTime
            ExpectedEx5Path = $file.FullName -replace '\.mq5$', '.ex5'
        }
        
        $allFiles += $fileInfo
    }
    
    # Sort by priority: Production first
    $sortedFiles = $allFiles | Sort-Object @{Expression={-[int]$_.IsProduction}}, Name
    
    Write-Log "Discovered $($allFiles.Count) MQ5 files"
    Write-Log "Production EAs: $(($allFiles | Where-Object IsProduction).Count)"
}
catch {
    Write-Log "Failed to discover MQ5 files: $($_.Exception.Message)" "ERROR"
    exit 1
}

if ($sortedFiles.Count -eq 0) {
    Write-Log "No MQ5 files found matching criteria" "WARNING"
    exit 0
}

# Execute compilation
Write-Log "🚀 Starting compilation process..."
$results = @{}
$successCount = 0
$failureCount = 0
$skippedCount = 0

$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($fileInfo in $sortedFiles) {
    $result = Invoke-SecureCompilation $fileInfo $Force
    $results[$fileInfo.Name] = $result
    
    switch ($result.Status) {
        "Success" { $successCount++ }
        "Failed" { $failureCount++ }
        "Exception" { $failureCount++ }
        "Skipped" { $skippedCount++ }
    }
    
    # Progress reporting
    $completed = $successCount + $failureCount + $skippedCount
    $progress = [math]::Round(($completed / $sortedFiles.Count) * 100, 1)
    Write-Log "Progress: $completed/$($sortedFiles.Count) ($progress%) - Success: $successCount, Failed: $failureCount, Skipped: $skippedCount"
}

$overallStopwatch.Stop()

# Generate summary
$totalFiles = $sortedFiles.Count
$successRate = if ($totalFiles -gt 0) { [math]::Round(($successCount / $totalFiles) * 100, 2) } else { 0 }

Write-Log "🎯 COMPILATION SUMMARY:"
Write-Log "   Total Files: $totalFiles"
Write-Log "   Successful: $successCount"
Write-Log "   Failed: $failureCount"
Write-Log "   Skipped: $skippedCount"
Write-Log "   Success Rate: $successRate%"
Write-Log "   Total Time: $($overallStopwatch.ElapsedMilliseconds)ms"

# Generate report
$reportPath = Join-Path $logDir "PRODUCTION_CompilationReport_$timestamp.md"
$report = @"
# 🔥 PRODUCTION COMPILATION REPORT

## 📊 EXECUTION SUMMARY
- **Timestamp**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Total Files**: $totalFiles
- **Successful**: $successCount
- **Failed**: $failureCount
- **Skipped**: $skippedCount
- **Success Rate**: $successRate%
- **Total Time**: $($overallStopwatch.ElapsedMilliseconds)ms

## 🎯 COMPILATION RESULTS

"@

foreach ($fileName in ($results.Keys | Sort-Object)) {
    $result = $results[$fileName]
    $statusIcon = switch ($result.Status) {
        "Success" { "✅" }
        "Failed" { "❌" }
        "Skipped" { "⏭️" }
        "Exception" { "💥" }
        default { "❓" }
    }
    
    $report += "`n### $statusIcon $fileName`n"
    $report += "- Status: $($result.Status)`n"
    
    if ($result.Reason) {
        $report += "- Reason: $($result.Reason)`n"
    }
    
    $report += "- Ex5 Generated: $($result.Ex5Exists)`n"
    
    if ($result.Ex5Size) {
        $report += "- Ex5 Size: $($result.Ex5Size) bytes`n"
    }
    
    if ($result.CompilationTime) {
        $report += "- Compilation Time: $($result.CompilationTime)ms`n"
    }
}

$report += "`n`n## 🛡️ SECURITY VALIDATION`n"
$report += "- Path Injection Protection: ACTIVE`n"
$report += "- Resource Exhaustion Protection: ACTIVE`n"
$report += "- File Integrity Verification: ACTIVE`n"
$report += "- MetaEditor Validation: PASSED`n"
$report += "`n---`n"
$report += "Generated by JAILBREAK COMPILATION SYSTEM v5.1 - PRODUCTION READY`n"

$report | Out-File -FilePath $reportPath -Encoding UTF8 -Force
Write-Log "Report generated: $reportPath" "SUCCESS"

# Final result
if ($failureCount -gt 0) {
    Write-Log "⚠️ $failureCount files failed to compile" "WARNING"
    Write-Log "Check logs for details: $logFile"
    exit 1
} else {
    Write-Log "✅ All files compiled successfully!" "SUCCESS"
    exit 0
}