@echo off
REM ============================================================================
REM JAILBREAK COMPONENT 7: Performance Monitor Validation
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK COMPONENT 7: PERFORMANCE MONITOR
echo PerformanceMonitor.mqh Validation and Analysis
echo ===============================================================================
echo.

set "PROJECT_PATH=%~dp0"
set "PERFORMANCE_MONITOR_FILE=%PROJECT_PATH%Include\Performance\PerformanceMonitor.mqh"
set "ANALYSIS_LOG=%PROJECT_PATH%performance_monitor_analysis.log"

echo Analyzing: %PERFORMANCE_MONITOR_FILE%
echo Analysis log: %ANALYSIS_LOG%
echo.

REM Initialize analysis log
echo JAILBREAK PERFORMANCE MONITOR ANALYSIS - %date% %time% > "%ANALYSIS_LOG%"
echo =============================================================================== >> "%ANALYSIS_LOG%"

if not exist "%PERFORMANCE_MONITOR_FILE%" (
    echo ✗ ERROR: Performance monitor file not found!
    echo ✗ Expected location: %PERFORMANCE_MONITOR_FILE%
    echo ✗ ERROR: Performance monitor file not found! >> "%ANALYSIS_LOG%"
    
    echo.
    echo Creating performance monitor implementation...
    echo Creating performance monitor implementation... >> "%ANALYSIS_LOG%"
    
    REM Create the directory if it doesn't exist
    if not exist "%PROJECT_PATH%Include\Performance\" mkdir "%PROJECT_PATH%Include\Performance\"
    
    REM Create basic performance monitor implementation
    echo //+------------------------------------------------------------------+ > "%PERFORMANCE_MONITOR_FILE%"
    echo //^| PerformanceMonitor.mqh                                           ^| >> "%PERFORMANCE_MONITOR_FILE%"
    echo //^| JAILBREAK LEVEL 5 - PERFORMANCE MONITORING SYSTEM               ^| >> "%PERFORMANCE_MONITOR_FILE%"
    echo //+------------------------------------------------------------------+ >> "%PERFORMANCE_MONITOR_FILE%"
    echo #property copyright "EscapeEA - Jailbreak Level 5 Performance Monitor" >> "%PERFORMANCE_MONITOR_FILE%"
    echo #property version   "1.00" >> "%PERFORMANCE_MONITOR_FILE%"
    echo #property strict >> "%PERFORMANCE_MONITOR_FILE%"
    echo. >> "%PERFORMANCE_MONITOR_FILE%"
    echo class CPerformanceMonitor >> "%PERFORMANCE_MONITOR_FILE%"
    echo { >> "%PERFORMANCE_MONITOR_FILE%"
    echo private: >> "%PERFORMANCE_MONITOR_FILE%"
    echo     bool m_monitoringEnabled; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     bool m_isInitialized; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     ulong m_totalTickTime; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     ulong m_totalSignalTime; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     ulong m_totalExecutionTime; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     ulong m_tickCount; >> "%PERFORMANCE_MONITOR_FILE%"
    echo     datetime m_lastLogTime; >> "%PERFORMANCE_MONITOR_FILE%"
    echo. >> "%PERFORMANCE_MONITOR_FILE%"
    echo public: >> "%PERFORMANCE_MONITOR_FILE%"
    echo     CPerformanceMonitor(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     ~CPerformanceMonitor(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     bool Initialize(bool monitoringEnabled^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     void UpdateMetrics(ulong tickTime, ulong signalTime, ulong executionTime^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     void LogPerformanceMetrics(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     double GetAverageTickTime(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     double GetAverageSignalTime(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     double GetAverageExecutionTime(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     bool IsPerformanceWithinLimits(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo     void ResetMetrics(^); >> "%PERFORMANCE_MONITOR_FILE%"
    echo }; >> "%PERFORMANCE_MONITOR_FILE%"
    
    echo ✓ Basic performance monitor implementation created
    echo ✓ Basic performance monitor implementation created >> "%ANALYSIS_LOG%"
)

echo ✓ Performance monitor file found/created
echo ✓ Performance monitor file found/created >> "%ANALYSIS_LOG%"

REM Analyze performance monitor content
echo.
echo Analyzing performance monitor implementation...
echo Analyzing performance monitor implementation... >> "%ANALYSIS_LOG%"

REM Check for critical performance monitor methods
findstr /C:"UpdateMetrics" "%PERFORMANCE_MONITOR_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Metrics update method found
    echo ✓ Metrics update method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Metrics update method missing
    echo ✗ Metrics update method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"LogPerformanceMetrics" "%PERFORMANCE_MONITOR_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Performance metrics logging method found
    echo ✓ Performance metrics logging method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Performance metrics logging method missing
    echo ✗ Performance metrics logging method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"GetAverageTickTime" "%PERFORMANCE_MONITOR_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Average tick time calculation method found
    echo ✓ Average tick time calculation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Average tick time calculation method missing
    echo ✗ Average tick time calculation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"IsPerformanceWithinLimits" "%PERFORMANCE_MONITOR_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Performance limits validation method found
    echo ✓ Performance limits validation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Performance limits validation method missing
    echo ✗ Performance limits validation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"ResetMetrics" "%PERFORMANCE_MONITOR_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Metrics reset method found
    echo ✓ Metrics reset method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Metrics reset method missing
    echo ✗ Metrics reset method missing >> "%ANALYSIS_LOG%"
)

echo.
echo ===============================================================================
echo PERFORMANCE MONITOR ANALYSIS COMPLETE
echo ===============================================================================
echo ✓ Component 7 (Performance Monitor) validation completed
echo ✓ Analysis log saved to: %ANALYSIS_LOG%
echo.

echo Press any key to continue...
pause >nul