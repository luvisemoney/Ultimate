@echo off
echo ===================================
echo EscapeEA Test Compilation Script
echo ===================================

set MT5_PATH="C:\Program Files\MetaTrader 5\MetaEditor64.exe"
set PROJECT_PATH=%~dp0..

echo Compiling Unit Tests...
echo.

echo Compiling TestSignalGenerator...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestSignalGenerator.mq5" /log

echo Compiling TestLogger...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestLogger.mq5" /log

echo Compiling TestHashMap...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestHashMap.mq5" /log

echo Compiling TestSignalBroadcaster...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestSignalBroadcaster.mq5" /log

echo Compiling existing unit tests...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestTradeExecutor.mq5" /log
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestRiskManager.mq5" /log
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestKnowledgeBase.mq5" /log
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestLearningEngine.mq5" /log
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Unit\TestAdvancedStrategy.mq5" /log

echo.
echo Compiling Integration Tests...
echo.

echo Compiling TestSignalToTradeFlow...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Integration\TestSignalToTradeFlow.mq5" /log

echo Compiling TestLearningSystemIntegration...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Integration\TestLearningSystemIntegration.mq5" /log

echo Compiling existing integration tests...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\Integration\TestPaperToLiveIntegration.mq5" /log

echo.
echo Compiling Test Suite Runner...
echo.

echo Compiling TestSuiteRunner...
%MT5_PATH% /compile:"%PROJECT_PATH%\Tests\TestSuiteRunner.mq5" /log

echo.
echo ===================================
echo Compilation Complete!
echo ===================================
echo.
echo Check the compilation logs for any errors.
echo If compilation is successful, you can run the tests using run_all_tests.bat
echo.
pause