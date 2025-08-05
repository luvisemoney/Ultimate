@echo off
echo ===================================
echo EscapeEA Quick Test Runner
echo ===================================

set MT5_PATH="C:\Program Files\MetaTrader 5\terminal64.exe"
set PROJECT_PATH=%~dp0..

echo Select which test to run:
echo.
echo 1. SignalGenerator Tests
echo 2. Logger Tests  
echo 3. HashMap Tests
echo 4. SignalBroadcaster Tests
echo 5. TradeExecutor Tests
echo 6. RiskManager Tests
echo 7. Signal-to-Trade Flow Integration
echo 8. Learning System Integration
echo 9. Complete Test Suite
echo 0. Exit
echo.

set /p choice="Enter your choice (0-9): "

if "%choice%"=="1" (
    echo Running SignalGenerator Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestSignalGenerator.ex5"
) else if "%choice%"=="2" (
    echo Running Logger Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestLogger.ex5"
) else if "%choice%"=="3" (
    echo Running HashMap Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestHashMap.ex5"
) else if "%choice%"=="4" (
    echo Running SignalBroadcaster Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestSignalBroadcaster.ex5"
) else if "%choice%"=="5" (
    echo Running TradeExecutor Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestTradeExecutor.ex5"
) else if "%choice%"=="6" (
    echo Running RiskManager Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Unit\TestRiskManager.ex5"
) else if "%choice%"=="7" (
    echo Running Signal-to-Trade Flow Integration Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Integration\TestSignalToTradeFlow.ex5"
) else if "%choice%"=="8" (
    echo Running Learning System Integration Tests...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\Integration\TestLearningSystemIntegration.ex5"
) else if "%choice%"=="9" (
    echo Running Complete Test Suite...
    %MT5_PATH% /script:"%PROJECT_PATH%\Tests\TestSuiteRunner.ex5"
) else if "%choice%"=="0" (
    echo Exiting...
    exit /b 0
) else (
    echo Invalid choice. Please try again.
    pause
    goto :eof
)

echo.
echo Test execution initiated. Check MetaTrader 5 Experts tab for results.
echo.
pause