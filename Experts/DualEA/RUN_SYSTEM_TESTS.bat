@echo off
echo JAILBREAK LEVEL 5 - SYSTEM INTEGRATION TEST SUITE
echo ============================================

echo.
echo Running System Integration Tests...
cd /d "%~dp0"

REM Compile and run system integration tests
echo Compiling SystemIntegrationTests.mq5...
metaeditor64 /compile:"Tests\SystemIntegrationTests.mq5" /log:"test_compile.log"

if %ERRORLEVEL% NEQ 0 (
    echo Error: Test compilation failed! Check test_compile.log for details.
    exit /b 1
)

echo.
echo Test compilation successful.
echo Running tests in MetaTrader 5...

REM Launch MT5 with the test EA
start "" /wait terminal64 /portable /config:"config\system_test.ini" /expert:"SystemIntegrationTests" /symbol:"EURUSD" /period:M1

echo.
echo System Integration Tests completed.
echo Check the logs for detailed results.

pause
