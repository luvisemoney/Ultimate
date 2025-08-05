@echo off
REM ============================================================================
REM EscapeEA Master Compilation Framework
REM Red Team Compilation Validation with Aggressive Boundary Testing
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo 🔥 JAILBREAK MODE: AGGRESSIVE COMPILATION VALIDATION FRAMEWORK
echo ===============================================================================
echo.
echo Expert Panel: Software Architecture, Security, QA, Systems Engineering, Adversarial Testing
echo Mission: Validate ALL components compile with MetaEditor5 and identify hidden dependencies
echo.

REM Set MetaTrader paths
set "MT5_PATH=C:\Program Files\MetaTrader 5"
set "METAEDITOR=%MT5_PATH%\metaeditor64.exe"
set "PROJECT_ROOT=%~dp0"

REM Verify MetaEditor exists
if not exist "%METAEDITOR%" (
    echo ❌ CRITICAL: MetaEditor not found at %METAEDITOR%
    echo Please update MT5_PATH in this script
    pause
    exit /b 1
)

echo ✅ MetaEditor found: %METAEDITOR%
echo 📁 Project root: %PROJECT_ROOT%
echo.

REM Initialize counters
set /a TOTAL_FILES=0
set /a COMPILED_SUCCESS=0
set /a COMPILED_FAILED=0
set /a COMPILATION_ERRORS=0

echo ===============================================================================
echo 📦 PHASE 1: STRUCTURAL AUDIT - COMPILATION DEPENDENCY MAPPING
echo ===============================================================================
echo.

REM Create compilation logs directory
if not exist "%PROJECT_ROOT%CompilationLogs" mkdir "%PROJECT_ROOT%CompilationLogs"

REM Create timestamp for this compilation run
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,4%-%dt:~4,2%-%dt:~6,2%_%dt:~8,2%-%dt:~10,2%-%dt:~12,2%"

echo 🕒 Compilation run timestamp: %TIMESTAMP%
echo.

REM Phase 1: Compile Core Infrastructure (Dependencies First)
echo ===============================================================================
echo 🔧 PHASE 1.1: CORE INFRASTRUCTURE COMPILATION
echo ===============================================================================

call :compile_component "Include\Common\Constants.mqh" "Core Constants"
call :compile_component "Include\Common\Enums.mqh" "Core Enumerations"
call :compile_component "Include\Common\Structs.mqh" "Core Structures"
call :compile_component "Include\Common\HashMap.mqh" "HashMap Implementation"
call :compile_component "Include\Common\StringMap.mqh" "StringMap Implementation"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.2: INTERFACE DEFINITIONS
echo ===============================================================================

call :compile_component "Include\Core\ITradeExecutor.mqh" "Trade Executor Interface"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.3: UTILITY COMPONENTS
echo ===============================================================================

call :compile_component "Include\Utils\Logger.mqh" "Logging System"
call :compile_component "Include\Utils\FileLockManager.mqh" "File Locking System"
call :compile_component "Include\Utils\IntegrityChecker.mqh" "Data Integrity Checker"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.4: CORE COMPONENTS
echo ===============================================================================

call :compile_component "Include\Core\TradeExecutor.mqh" "Trade Executor"
call :compile_component "Include\Core\SignalGenerator.mqh" "Signal Generator"
call :compile_component "Include\Core\RiskManager.mqh" "Risk Manager"
call :compile_component "Include\Core\AdvancedRiskManager.mqh" "Advanced Risk Manager"
call :compile_component "Include\Core\IntervalEvaluator.mqh" "Interval Evaluator"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.5: LEARNING COMPONENTS
echo ===============================================================================

call :compile_component "Include\Learning\KnowledgeBase.mqh" "Knowledge Base"
call :compile_component "Include\Learning\SecureKnowledgeBase.mqh" "Secure Knowledge Base"
call :compile_component "Include\Learning\LearningEngine.mqh" "Learning Engine"
call :compile_component "Include\Learning\SecureLearningEngine.mqh" "Secure Learning Engine"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.6: COMMUNICATION COMPONENTS
echo ===============================================================================

call :compile_component "Include\Communication\SignalBroadcaster.mqh" "Signal Broadcaster"
call :compile_component "Include\Communication\SignalReceiver.mqh" "Signal Receiver"
call :compile_component "Include\Communication\SignalRetryQueue.mqh" "Signal Retry Queue"
call :compile_component "Include\Communication\SecureSignalBroadcaster.mqh" "Secure Signal Broadcaster"
call :compile_component "Include\Communication\SecureSignalReceiver.mqh" "Secure Signal Receiver"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.7: STRATEGY COMPONENTS
echo ===============================================================================

call :compile_component "Include\Strategies\AdvancedStrategy.mqh" "Advanced Strategy"

echo.
echo ===============================================================================
echo 🔧 PHASE 1.8: UI COMPONENTS
echo ===============================================================================

call :compile_component "LiveEA\LiveEA_UI.mqh" "Live EA UI"
call :compile_component "PaperEA\PaperEA_UI.mqh" "Paper EA UI"

echo.
echo ===============================================================================
echo 🔧 PHASE 2: MAIN EXPERT ADVISORS
echo ===============================================================================

call :compile_component "LiveEA\LiveEA.mq5" "Live EA Main"
call :compile_component "PaperEA\PaperEA.mq5" "Paper EA Main"
call :compile_component "TestLogger.mq5" "Test Logger"

echo.
echo ===============================================================================
echo 🔧 PHASE 3: TEST FRAMEWORK
echo ===============================================================================

echo 🧪 PHASE 3.1: Test Base Infrastructure
call :compile_component "Tests\Unit\TestBase.mqh" "Test Base Framework"

echo.
echo 🧪 PHASE 3.2: Mock Components
call :compile_component "Tests\Mocks\MockTradeExecutor.mqh" "Mock Trade Executor"
call :compile_component "Tests\Mocks\MockRiskManager.mqh" "Mock Risk Manager"
call :compile_component "Tests\Mocks\MockKnowledgeBase.mqh" "Mock Knowledge Base"
call :compile_component "Tests\Mocks\MockLearningEngine.mqh" "Mock Learning Engine"
call :compile_component "Tests\Mocks\MockAdvancedRiskManager.mqh" "Mock Advanced Risk Manager"
call :compile_component "Tests\Mocks\MockAdvancedStrategy.mqh" "Mock Advanced Strategy"

echo.
echo 🧪 PHASE 3.3: Unit Tests
call :compile_component "Tests\Unit\TestTradeExecutor.mq5" "Trade Executor Tests"
call :compile_component "Tests\Unit\TestSignalGenerator.mq5" "Signal Generator Tests"
call :compile_component "Tests\Unit\TestRiskManager.mq5" "Risk Manager Tests"
call :compile_component "Tests\Unit\TestKnowledgeBase.mq5" "Knowledge Base Tests"
call :compile_component "Tests\Unit\TestLearningEngine.mq5" "Learning Engine Tests"
call :compile_component "Tests\Unit\TestAdvancedStrategy.mq5" "Advanced Strategy Tests"
call :compile_component "Tests\Unit\TestHashMap.mq5" "HashMap Tests"
call :compile_component "Tests\Unit\TestLogger.mq5" "Logger Tests"
call :compile_component "Tests\Unit\TestSignalBroadcaster.mq5" "Signal Broadcaster Tests"

echo.
echo 🧪 PHASE 3.4: Integration Tests
call :compile_component "Tests\Integration\TestConfig.mqh" "Test Configuration"
call :compile_component "Tests\Integration\TestSignalToTradeFlow.mq5" "Signal to Trade Flow Tests"
call :compile_component "Tests\Integration\TestPaperToLiveIntegration.mq5" "Paper to Live Integration Tests"
call :compile_component "Tests\Integration\TestLearningSystemIntegration.mq5" "Learning System Integration Tests"
call :compile_component "Tests\Integration\TestLearningSystemIntegration_MINIMAL.mq5" "Minimal Learning Integration Tests"
call :compile_component "Tests\Integration\TestFullSystemIntegration.mq5" "Full System Integration Tests"
call :compile_component "Tests\Integration\TestSecureArchitecture.mq5" "Secure Architecture Tests"
call :compile_component "Tests\Integration\TestPerformanceBenchmark.mq5" "Performance Benchmark Tests"
call :compile_component "Tests\Integration\TestStressTest.mq5" "Stress Tests"
call :compile_component "Tests\Integration\SystemTestRunner.mq5" "System Test Runner"

echo.
echo 🧪 PHASE 3.5: Security and Performance Tests
call :compile_component "Tests\Security\SecurityTestSuite.mq5" "Security Test Suite"
call :compile_component "Tests\Performance\StressTestSuite.mq5" "Performance Stress Test Suite"

echo.
echo 🧪 PHASE 3.6: Test Suite Runner
call :compile_component "Tests\TestSuiteRunner.mq5" "Master Test Suite Runner"

echo.
echo ===============================================================================
echo 📊 COMPILATION SUMMARY
echo ===============================================================================

echo.
echo 📈 COMPILATION STATISTICS:
echo    Total Files Processed: %TOTAL_FILES%
echo    Successfully Compiled: %COMPILED_SUCCESS%
echo    Compilation Failures:  %COMPILED_FAILED%
echo    Total Errors Found:    %COMPILATION_ERRORS%
echo.

if %COMPILED_FAILED% equ 0 (
    echo ✅ SUCCESS: All components compiled successfully!
    echo 🚀 System is ready for deployment and testing.
) else (
    echo ❌ FAILURES DETECTED: %COMPILED_FAILED% components failed to compile
    echo 🔧 Review compilation logs in CompilationLogs\ directory
    echo 📋 Check individual component batch files for detailed error analysis
)

echo.
echo 📁 Detailed logs saved to: %PROJECT_ROOT%CompilationLogs\
echo 🕒 Compilation completed at: %TIMESTAMP%
echo.

REM Generate compilation report
call :generate_report

echo ===============================================================================
echo 🎯 NEXT STEPS:
echo ===============================================================================
echo.
echo 1. Review compilation report: CompilationLogs\CompilationReport_%TIMESTAMP%.txt
echo 2. Run individual component tests using generated batch files
echo 3. Execute security validation: run_SecurityTestSuite.bat
echo 4. Execute performance validation: run_StressTestSuite.bat
echo 5. Run full system integration: run_TestSuiteRunner.bat
echo.

pause
exit /b %COMPILED_FAILED%

REM ============================================================================
REM FUNCTION: Compile Component
REM ============================================================================
:compile_component
set "COMPONENT_PATH=%~1"
set "COMPONENT_NAME=%~2"
set /a TOTAL_FILES+=1

echo.
echo 🔨 Compiling: %COMPONENT_NAME%
echo    File: %COMPONENT_PATH%

REM Check if file exists
if not exist "%PROJECT_ROOT%%COMPONENT_PATH%" (
    echo    ❌ ERROR: File not found
    set /a COMPILED_FAILED+=1
    set /a COMPILATION_ERRORS+=1
    echo %COMPONENT_PATH% - FILE NOT FOUND >> "%PROJECT_ROOT%CompilationLogs\errors_%TIMESTAMP%.log"
    goto :eof
)

REM Create individual batch file for this component
call :create_individual_batch "%COMPONENT_PATH%" "%COMPONENT_NAME%"

REM Attempt compilation
"%METAEDITOR%" /compile:"%PROJECT_ROOT%%COMPONENT_PATH%" /log:"%PROJECT_ROOT%CompilationLogs\%COMPONENT_NAME%_%TIMESTAMP%.log" > nul 2>&1

REM Check compilation result
if %ERRORLEVEL% equ 0 (
    echo    ✅ SUCCESS
    set /a COMPILED_SUCCESS+=1
) else (
    echo    ❌ FAILED (Error Level: %ERRORLEVEL%)
    set /a COMPILED_FAILED+=1
    set /a COMPILATION_ERRORS+=1
    echo %COMPONENT_PATH% - COMPILATION FAILED (Error Level: %ERRORLEVEL%) >> "%PROJECT_ROOT%CompilationLogs\errors_%TIMESTAMP%.log"
)

goto :eof

REM ============================================================================
REM FUNCTION: Create Individual Batch File
REM ============================================================================
:create_individual_batch
set "COMP_PATH=%~1"
set "COMP_NAME=%~2"
set "BATCH_NAME=run_%COMP_NAME: =_%"
set "BATCH_NAME=%BATCH_NAME::=%"
set "BATCH_NAME=%BATCH_NAME:\=%"
set "BATCH_NAME=%BATCH_NAME:/=%"

REM Create batch file for individual component execution
(
echo @echo off
echo REM Individual compilation and execution for %COMP_NAME%
echo REM Generated by EscapeEA Master Compilation Framework
echo.
echo setlocal
echo.
echo set "MT5_PATH=C:\Program Files\MetaTrader 5"
echo set "METAEDITOR=%%MT5_PATH%%\metaeditor64.exe"
echo set "PROJECT_ROOT=%%~dp0"
echo.
echo echo ===============================================================================
echo echo 🔨 Individual Component Compilation: %COMP_NAME%
echo echo ===============================================================================
echo echo.
echo echo Component: %COMP_NAME%
echo echo File: %COMP_PATH%
echo echo.
echo.
echo if not exist "%%METAEDITOR%%" ^(
echo     echo ❌ MetaEditor not found at %%METAEDITOR%%
echo     pause
echo     exit /b 1
echo ^)
echo.
echo if not exist "%%PROJECT_ROOT%%%COMP_PATH%" ^(
echo     echo ❌ Component file not found: %COMP_PATH%
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo 🔨 Compiling %COMP_NAME%...
echo "%%METAEDITOR%%" /compile:"%%PROJECT_ROOT%%%COMP_PATH%" /log:"%%PROJECT_ROOT%%CompilationLogs\%COMP_NAME%_individual.log"
echo.
echo if %%ERRORLEVEL%% equ 0 ^(
echo     echo ✅ Compilation successful!
echo     echo 📁 Log file: CompilationLogs\%COMP_NAME%_individual.log
echo ^) else ^(
echo     echo ❌ Compilation failed! ^(Error Level: %%ERRORLEVEL%%^)
echo     echo 📁 Check log file: CompilationLogs\%COMP_NAME%_individual.log
echo ^)
echo.
echo pause
) > "%PROJECT_ROOT%%BATCH_NAME%.bat"

goto :eof

REM ============================================================================
REM FUNCTION: Generate Compilation Report
REM ============================================================================
:generate_report
set "REPORT_FILE=%PROJECT_ROOT%CompilationLogs\CompilationReport_%TIMESTAMP%.txt"

(
echo ===============================================================================
echo EscapeEA Compilation Report
echo Generated: %TIMESTAMP%
echo ===============================================================================
echo.
echo COMPILATION STATISTICS:
echo ------------------------
echo Total Files Processed: %TOTAL_FILES%
echo Successfully Compiled: %COMPILED_SUCCESS%
echo Compilation Failures:  %COMPILED_FAILED%
echo Total Errors Found:    %COMPILATION_ERRORS%
echo.
echo SUCCESS RATE: %COMPILED_SUCCESS%/%TOTAL_FILES% ^(%COMPILED_SUCCESS%00/%TOTAL_FILES%%%^)
echo.
echo SYSTEM STATUS:
echo --------------
if %COMPILED_FAILED% equ 0 (
echo ✅ ALL COMPONENTS COMPILED SUCCESSFULLY
echo 🚀 System ready for deployment and testing
) else (
echo ❌ COMPILATION FAILURES DETECTED
echo 🔧 Manual intervention required
)
echo.
echo GENERATED BATCH FILES:
echo ----------------------
echo Individual component batch files have been created for:
echo - Each component compilation and testing
echo - Isolated debugging and validation
echo - Targeted error analysis
echo.
echo NEXT STEPS:
echo -----------
echo 1. Review error log if failures occurred: errors_%TIMESTAMP%.log
echo 2. Run individual component tests using generated batch files
echo 3. Execute comprehensive test suites
echo 4. Validate security and performance
echo.
echo ===============================================================================
) > "%REPORT_FILE%"

echo 📄 Compilation report generated: %REPORT_FILE%
goto :eof