@echo off
echo ===================================
echo EscapeEA Test Execution Script
echo ===================================

set MT5_PATH="C:\Program Files\MetaTrader 5\terminal64.exe"
set PROJECT_PATH=%~dp0..

echo Starting comprehensive test execution...
echo.

echo ===================================
echo Running Unit Tests
echo ===================================
echo.

echo Running SignalGenerator Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestSignalGenerator.ex5"
timeout /t 5 /nobreak > nul

echo Running Logger Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestLogger.ex5"
timeout /t 5 /nobreak > nul

echo Running HashMap Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestHashMap.ex5"
timeout /t 5 /nobreak > nul

echo Running SignalBroadcaster Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestSignalBroadcaster.ex5"
timeout /t 5 /nobreak > nul

echo Running TradeExecutor Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestTradeExecutor.ex5"
timeout /t 5 /nobreak > nul

echo Running RiskManager Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestRiskManager.ex5"
timeout /t 5 /nobreak > nul

echo Running KnowledgeBase Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestKnowledgeBase.ex5"
timeout /t 5 /nobreak > nul

echo Running LearningEngine Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestLearningEngine.ex5"
timeout /t 5 /nobreak > nul

echo Running AdvancedStrategy Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestAdvancedStrategy.ex5"
timeout /t 5 /nobreak > nul

echo.
echo ===================================
echo Running Integration Tests
echo ===================================
echo.

echo Running SignalToTradeFlow Integration Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Integration\TestSignalToTradeFlow.ex5"
timeout /t 10 /nobreak > nul

echo Running LearningSystem Integration Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Integration\TestLearningSystemIntegration.ex5"
timeout /t 10 /nobreak > nul

echo Running PaperToLive Integration Tests...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\Integration\TestPaperToLiveIntegration.ex5"
timeout /t 10 /nobreak > nul

echo.
echo ===================================
echo Running Complete Test Suite
echo ===================================
echo.

echo Running Test Suite Runner (Comprehensive)...
%MT5_PATH% /script:"%PROJECT_PATH%\Tests\TestSuiteRunner.ex5"
timeout /t 15 /nobreak > nul

echo.
echo ===================================
echo Test Execution Complete!
echo ===================================
echo.
echo Check the following locations for test results:
echo - MetaTrader 5 Experts tab for console output
echo - TestLogs folder for detailed logs
echo - TestLogs\Suite folder for comprehensive reports
echo.
echo Individual test results are also available in their respective log files.
echo.
pause