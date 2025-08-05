# Compile-All.ps1 - Compile all EscapeEA components

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$components = @(
    @{Name = "PaperEA"; Script = "compile.bat"; Output = "PaperEA.ex5"},
    @{Name = "LiveEA"; Script = "compile.bat"; Output = "LiveEA.ex5"},
    @{Name = "Tests"; Script = "compile.bat"; Output = "RunTestsScript.ex5"},
    @{Name = "Learning Module"; Path = "Include\Learning"; Script = "compile.bat"; IsModule = $true}
)

function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] $Status $Message"
}

function Test-ComponentExists {
    param($component)
    
    $path = if ($component.ContainsKey('Path')) {
        Join-Path $baseDir $component.Path
    } else {
        Join-Path $baseDir $component.Name
    }
    
    $scriptPath = Join-Path $path $component.Script
    
    if (-not (Test-Path $path)) {
        Write-Status "[ERROR]" "$($component.Name) directory not found at: $path"
        return $false
    }
    
    if (-not (Test-Path $scriptPath)) {
        Write-Status "[ERROR]" "$($component.Name) compile script not found at: $scriptPath"
        return $false
    }
    
    return $true
}

function Compile-Component {
    param($component)
    
    Write-Host "`n$(('=' * 80))"
    Write-Host "COMPILING $($component.Name)"
    Write-Host "$(('=' * 80))"
    
    $originalLocation = Get-Location
    $path = if ($component.ContainsKey('Path')) {
        Join-Path $baseDir $component.Path
    } else {
        Join-Path $baseDir $component.Name
    }
    
    try {
        Set-Location $path
        
        # Run the compile script
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $($component.Script)" -NoNewWindow -Wait -PassThru
        
        # Check for output file if specified
        $success = $true
        if ($component.ContainsKey('Output')) {
            $outputFile = Join-Path $path $component.Output
            $success = Test-Path $outputFile
        }
        
        if ($process.ExitCode -eq 0 -and $success) {
            Write-Status "[SUCCESS]" "$($component.Name) compiled successfully"
            return $true
        } else {
            Write-Status "[ERROR]" "$($component.Name) compilation failed with exit code $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Status "[ERROR]" "Failed to compile $($component.Name): $_"
        return $false
    }
    finally {
        Set-Location $originalLocation
    }
}

# Main execution
Write-Host "`n$(('=' * 80))"
Write-Host "ESCAPEEA COMPILATION SCRIPT"
Write-Host "$(('=' * 80))"
Write-Host "Starting compilation at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$results = @()
$successCount = 0

foreach ($component in $components) {
    if (Test-ComponentExists $component) {
        $startTime = Get-Date
        
        Write-Status "[START]" "Compiling $($component.Name)..."
        $success = Compile-Component $component
        
        $duration = (Get-Date) - $startTime
        $status = if ($success) { "SUCCESS" } else { "FAILED" }
        
        $results += [PSCustomObject]@{
            Component = $component.Name
            Status = $status
            Duration = $duration.ToString("hh\:mm\:ss") 
        }
        
        if ($success) { $successCount++ }
    } else {
        $results += [PSCustomObject]@{
            Component = $component.Name
            Status = "NOT FOUND"
            Duration = "N/A"
        }
    }
}

# Print summary
Write-Host "`n$(('=' * 80))"
Write-Host "COMPILATION SUMMARY"
Write-Host "$(('=' * 80))"

$results | Format-Table -AutoSize

Write-Host "`n$(('=' * 80))"
if ($successCount -eq $components.Count) {
    Write-Host "ALL COMPONENTS COMPILED SUCCESSFULLY!" -ForegroundColor Green
} else {
    Write-Host "$successCount of $($components.Count) components compiled successfully" -ForegroundColor Yellow
    
    $failed = $results | Where-Object { $_.Status -ne "SUCCESS" }
    if ($failed) {
        Write-Host "`nFailed components:" -ForegroundColor Red
        $failed | ForEach-Object { 
            Write-Host "- $($_.Component): $($_.Status)" -ForegroundColor Red 
        }
    }
}
Write-Host "$(('=' * 80))"

# Exit with error code if any component failed
exit ($components.Count - $successCount)
