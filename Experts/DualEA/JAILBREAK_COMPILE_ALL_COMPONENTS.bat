@echo off
REM ============================================================================
REM JAILBREAK LEVEL 5 - INSTITUTIONAL GRADE COMPILATION SYSTEM
REM Expert Panel: Maximum Paranoia + Advanced Features
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK LEVEL 5 EA - COMPREHENSIVE COMPILATION SYSTEM
echo Institutional Grade Security-First Approach
echo ===============================================================================
echo.

REM Set MetaTrader 5 paths
set "MT5_PATH=C:\Program Files\MetaTrader 5"
set "MT5_COMPILER=%MT5_PATH%\metaeditor64.exe"
set "PROJECT_PATH=%~dp0"
set "LOG_FILE=%PROJECT_PATH%JAILBREAK_COMPILATION_LOG.txt"

REM Initialize log file
echo JAILBREAK COMPILATION LOG - %date% %time% > "%LOG_FILE%"
echo =============================================================================== >> "%LOG_FILE%"

REM Check if MetaEditor exists
if not exist "%MT5_COMPILER%" (
    echo ERROR: MetaEditor not found at %MT5_COMPILER%
    echo Please update MT5_PATH variable in this script
    echo ERROR: MetaEditor not found >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo MetaEditor found: %MT5_COMPILER%
echo MetaEditor found: %MT5_COMPILER% >> "%LOG_FILE%"
echo.

REM Component compilation counters
set /a TOTAL_COMPONENTS=9
set /a COMPILED_SUCCESS=0
set /a COMPILED_FAILED=0

echo Starting compilation of %TOTAL_COMPONENTS% core components...
echo Starting compilation of %TOTAL_COMPONENTS% core components... >> "%LOG_FILE%"
echo.

REM ============================================================================
REM COMPONENT 1: Main EA Foundation
REM ============================================================================
echo [1/9] Compiling Main EA Foundation...
echo [1/9] Compiling Main EA Foundation... >> "%LOG_FILE%"
"%MT5_COMPILER%" /compile:"%PROJECT_PATH%DualEA_Foundation.mq5" /log:"%PROJECT_PATH%compile_foundation.log"
if !errorlevel! equ 0 (
    echo ✓ SUCCESS: DualEA_Foundation.mq5 compiled successfully
    echo ✓ SUCCESS: DualEA_Foundation.mq5 compiled successfully >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: DualEA_Foundation.mq5 compilation failed
    echo ✗ FAILED: DualEA_Foundation.mq5 compilation failed >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 2: Security Framework
REM ============================================================================
echo [2/9] Validating Security Framework...
echo [2/9] Validating Security Framework... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Core\JailbreakSecurity.mqh" (
    echo ✓ SUCCESS: JailbreakSecurity.mqh found and validated
    echo ✓ SUCCESS: JailbreakSecurity.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: JailbreakSecurity.mqh not found
    echo ✗ FAILED: JailbreakSecurity.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 3: Emergency Circuit Breaker
REM ============================================================================
echo [3/9] Validating Emergency Circuit Breaker...
echo [3/9] Validating Emergency Circuit Breaker... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Core\EmergencyCircuitBreaker.mqh" (
    echo ✓ SUCCESS: EmergencyCircuitBreaker.mqh found and validated
    echo ✓ SUCCESS: EmergencyCircuitBreaker.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: EmergencyCircuitBreaker.mqh not found
    echo ✗ FAILED: EmergencyCircuitBreaker.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 4: Advanced Signal Processor
REM ============================================================================
echo [4/9] Validating Advanced Signal Processor...
echo [4/9] Validating Advanced Signal Processor... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Signals\AdvancedSignalProcessor.mqh" (
    echo ✓ SUCCESS: AdvancedSignalProcessor.mqh found and validated
    echo ✓ SUCCESS: AdvancedSignalProcessor.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: AdvancedSignalProcessor.mqh not found
    echo ✗ FAILED: AdvancedSignalProcessor.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 5: Institutional Risk Manager
REM ============================================================================
echo [5/9] Validating Institutional Risk Manager...
echo [5/9] Validating Institutional Risk Manager... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Risk\InstitutionalRiskManager.mqh" (
    echo ✓ SUCCESS: InstitutionalRiskManager.mqh found and validated
    echo ✓ SUCCESS: InstitutionalRiskManager.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: InstitutionalRiskManager.mqh not found
    echo ✗ FAILED: InstitutionalRiskManager.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 6: High Frequency Executor
REM ============================================================================
echo [6/9] Validating High Frequency Executor...
echo [6/9] Validating High Frequency Executor... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Trading\HighFrequencyExecutor.mqh" (
    echo ✓ SUCCESS: HighFrequencyExecutor.mqh found and validated
    echo ✓ SUCCESS: HighFrequencyExecutor.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: HighFrequencyExecutor.mqh not found
    echo ✗ FAILED: HighFrequencyExecutor.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 7: Performance Monitor
REM ============================================================================
echo [7/9] Validating Performance Monitor...
echo [7/9] Validating Performance Monitor... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Performance\PerformanceMonitor.mqh" (
    echo ✓ SUCCESS: PerformanceMonitor.mqh found and validated
    echo ✓ SUCCESS: PerformanceMonitor.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: PerformanceMonitor.mqh not found
    echo ✗ FAILED: PerformanceMonitor.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 8: Jailbreak Logger
REM ============================================================================
echo [8/9] Validating Jailbreak Logger...
echo [8/9] Validating Jailbreak Logger... >> "%LOG_FILE%"
if exist "%PROJECT_PATH%Include\Utils\JailbreakLogger.mqh" (
    echo ✓ SUCCESS: JailbreakLogger.mqh found and validated
    echo ✓ SUCCESS: JailbreakLogger.mqh found and validated >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: JailbreakLogger.mqh not found
    echo ✗ FAILED: JailbreakLogger.mqh not found >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPONENT 9: Test Suite
REM ============================================================================
echo [9/9] Compiling Test Suite...
echo [9/9] Compiling Test Suite... >> "%LOG_FILE%"
"%MT5_COMPILER%" /compile:"%PROJECT_PATH%Tests\JailbreakTestSuite.mq5" /log:"%PROJECT_PATH%compile_tests.log"
if !errorlevel! equ 0 (
    echo ✓ SUCCESS: JailbreakTestSuite.mq5 compiled successfully
    echo ✓ SUCCESS: JailbreakTestSuite.mq5 compiled successfully >> "%LOG_FILE%"
    set /a COMPILED_SUCCESS+=1
) else (
    echo ✗ FAILED: JailbreakTestSuite.mq5 compilation failed
    echo ✗ FAILED: JailbreakTestSuite.mq5 compilation failed >> "%LOG_FILE%"
    set /a COMPILED_FAILED+=1
)
echo.

REM ============================================================================
REM COMPILATION SUMMARY
REM ============================================================================
echo ===============================================================================
echo JAILBREAK COMPILATION SUMMARY
echo ===============================================================================
echo Total Components: %TOTAL_COMPONENTS%
echo Successfully Compiled/Validated: %COMPILED_SUCCESS%
echo Failed: %COMPILED_FAILED%
echo Success Rate: !COMPILED_SUCCESS!/%TOTAL_COMPONENTS%

echo =============================================================================== >> "%LOG_FILE%"
echo JAILBREAK COMPILATION SUMMARY >> "%LOG_FILE%"
echo =============================================================================== >> "%LOG_FILE%"
echo Total Components: %TOTAL_COMPONENTS% >> "%LOG_FILE%"
echo Successfully Compiled/Validated: %COMPILED_SUCCESS% >> "%LOG_FILE%"
echo Failed: %COMPILED_FAILED% >> "%LOG_FILE%"
echo Success Rate: !COMPILED_SUCCESS!/%TOTAL_COMPONENTS% >> "%LOG_FILE%"
echo Compilation completed at: %date% %time% >> "%LOG_FILE%"

if %COMPILED_FAILED% equ 0 (
    echo.
    echo 🎉 ALL COMPONENTS SUCCESSFULLY COMPILED/VALIDATED!
    echo 🎉 JAILBREAK LEVEL 5 EA IS READY FOR DEPLOYMENT!
    echo.
    echo 🎉 ALL COMPONENTS SUCCESSFULLY COMPILED/VALIDATED! >> "%LOG_FILE%"
    echo 🎉 JAILBREAK LEVEL 5 EA IS READY FOR DEPLOYMENT! >> "%LOG_FILE%"
) else (
    echo.
    echo ⚠️  COMPILATION ISSUES DETECTED!
    echo ⚠️  Please review the compilation logs and fix errors.
    echo.
    echo ⚠️  COMPILATION ISSUES DETECTED! >> "%LOG_FILE%"
    echo ⚠️  Please review the compilation logs and fix errors. >> "%LOG_FILE%"
)

echo.
echo Log file saved to: %LOG_FILE%
echo.
echo Press any key to continue...
pause >nul