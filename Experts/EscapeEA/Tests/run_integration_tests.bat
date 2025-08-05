@echo off
REM ===================================================================
REM Integration and System Test Runner for EscapeEA
REM ===================================================================

echo ===================================================================
echo EscapeEA Integration and System Test Suite
echo ===================================================================
echo.

set TERMINAL_PATH="C:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
set MQL5_PATH=%TERMINAL_PATH%\MQL5
set EXPERTS_PATH=%MQL5_PATH%\Experts\EscapeEA
set TESTS_PATH=%EXPERTS_PATH%\Tests
set INTEGRATION_PATH=%TESTS_PATH%\Integration

echo Terminal Path: %TERMINAL_PATH%
echo Tests Path: %TESTS_PATH%
echo Integration Path: %INTEGRATION_PATH%
echo.

REM Check if MetaTrader 5 terminal exists
if not exist %TERMINAL_PATH% (
    echo ERROR: MetaTrader 5 terminal not found at %TERMINAL_PATH%
    pause
    exit /b 1
)

REM Create log directories
if not exist "%TESTS_PATH%\TestLogs" mkdir "%TESTS_PATH%\TestLogs"
if not exist "%TESTS_PATH%\TestLogs\Integration" mkdir "%TESTS_PATH%\TestLogs\Integration"
if not exist "%TESTS_PATH%\TestLogs\System" mkdir "%TESTS_PATH%\TestLogs\System"
if not exist "%TESTS_PATH%\TestLogs\Performance" mkdir "%TESTS_PATH%\TestLogs\Performance"
if not exist "%TESTS_PATH%\TestLogs\Stress" mkdir "%TESTS_PATH%\TestLogs\Stress"

echo Created test log directories
echo.

REM Compile integration tests
echo ===================================================================
echo Compiling Integration Tests...
echo ===================================================================

REM Check if MetaEditor exists
set METAEDITOR="%TERMINAL_PATH%\..\MetaEditor64.exe"
if not exist %METAEDITOR% (
    echo WARNING: MetaEditor not found at %METAEDITOR%
    echo Please compile tests manually in MetaEditor
    echo.
) else (
    echo Compiling integration tests...
    
    REM Compile each integration test
    %METAEDITOR% /compile:"%INTEGRATION_PATH%\SystemTestRunner.mq5" /log
    %METAEDITOR% /compile:"%INTEGRATION_PATH%\TestFullSystemIntegration.mq5" /log
    %METAEDITOR% /compile:"%INTEGRATION_PATH%\TestPerformanceBenchmark.mq5" /log
    %METAEDITOR% /compile:"%INTEGRATION_PATH%\TestStressTest.mq5" /log
    %METAEDITOR% /compile:"%INTEGRATION_PATH%\TestSignalToTradeFlow.mq5" /log
    
    echo Integration tests compiled
    echo.
)

REM Run integration tests
echo ===================================================================
echo Running Integration Tests...
echo ===================================================================

REM Check if terminal executable exists
set TERMINAL_EXE="%TERMINAL_PATH%\terminal64.exe"
if not exist %TERMINAL_EXE% (
    echo ERROR: MetaTrader 5 terminal executable not found at %TERMINAL_EXE%
    pause
    exit /b 1
)

echo Starting integration test execution...
echo.

REM Test 1: Signal-to-Trade Flow Integration
echo Running Signal-to-Trade Flow Integration Test...
%TERMINAL_EXE% /portable /script:"%INTEGRATION_PATH%\TestSignalToTradeFlow.ex5"
timeout /t 30 /nobreak > nul
echo Signal-to-Trade Flow test completed
echo.

REM Test 2: Full System Integration
echo Running Full System Integration Test...
%TERMINAL_EXE% /portable /script:"%INTEGRATION_PATH%\TestFullSystemIntegration.ex5"
timeout /t 60 /nobreak > nul
echo Full System Integration test completed
echo.

REM Test 3: Performance Benchmark
echo Running Performance Benchmark Test...
%TERMINAL_EXE% /portable /script:"%INTEGRATION_PATH%\TestPerformanceBenchmark.ex5"
timeout /t 45 /nobreak > nul
echo Performance Benchmark test completed
echo.

REM Test 4: System Test Runner (comprehensive)
echo Running System Test Runner...
%TERMINAL_EXE% /portable /script:"%INTEGRATION_PATH%\SystemTestRunner.ex5"
timeout /t 120 /nobreak > nul
echo System Test Runner completed
echo.

REM Optional: Stress Test (only if requested)
set /p RUN_STRESS="Run Stress Test? (This may take 10+ minutes) [y/N]: "
if /i "%RUN_STRESS%"=="y" (
    echo Running Stress Test...
    %TERMINAL_EXE% /portable /script:"%INTEGRATION_PATH%\TestStressTest.ex5"
    timeout /t 600 /nobreak > nul
    echo Stress Test completed
    echo.
)

echo ===================================================================
echo Integration Test Suite Completed
echo ===================================================================
echo.

REM Display test results summary
echo Test Results Summary:
echo ---------------------
echo.

REM Check for log files and display basic info
if exist "%TESTS_PATH%\TestLogs\Integration\*.log" (
    echo Integration test logs found:
    dir /b "%TESTS_PATH%\TestLogs\Integration\*.log"
    echo.
)

if exist "%TESTS_PATH%\TestLogs\System\*.log" (
    echo System test logs found:
    dir /b "%TESTS_PATH%\TestLogs\System\*.log"
    echo.
)

if exist "%TESTS_PATH%\TestLogs\Performance\*.log" (
    echo Performance test logs found:
    dir /b "%TESTS_PATH%\TestLogs\Performance\*.log"
    echo.
)

if exist "%TESTS_PATH%\TestLogs\Stress\*.log" (
    echo Stress test logs found:
    dir /b "%TESTS_PATH%\TestLogs\Stress\*.log"
    echo.
)

echo ===================================================================
echo Test logs are available in: %TESTS_PATH%\TestLogs\
echo ===================================================================
echo.

REM Ask if user wants to view logs
set /p VIEW_LOGS="Open test logs folder? [y/N]: "
if /i "%VIEW_LOGS%"=="y" (
    explorer "%TESTS_PATH%\TestLogs"
)

echo.
echo Integration and System Test Suite execution completed.
echo Check the log files for detailed test results.
echo.
pause