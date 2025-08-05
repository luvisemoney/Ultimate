@echo off
echo === JAILBREAK LEVEL 5 EA COMPILATION START ===

REM Set MetaEditor path
set METAEDITOR="C:\Program Files\MetaTrader 5\MetaEditor64.exe"

REM Ensure MetaEditor exists
if not exist %METAEDITOR% (
    echo ERROR: MetaEditor not found at %METAEDITOR%
    exit /b 1
)

echo Compiling DualEA components...

REM Compile foundation EA
echo [1/8] Compiling DualEA_Foundation.mq5...
%METAEDITOR% /compile:"DualEA_Foundation.mq5" /log:"compile_foundation.log"
if errorlevel 1 (
    echo ERROR: Foundation compilation failed. Check compile_foundation.log for details.
    exit /b 1
)

REM Compile test suite
echo [2/8] Compiling test suite...
%METAEDITOR% /compile:"Tests\JailbreakTestSuite.mq5" /log:"compile_tests.log"
if errorlevel 1 (
    echo ERROR: Test suite compilation failed. Check compile_tests.log for details.
    exit /b 1
)

echo.
echo === JAILBREAK LEVEL 5 EA COMPILATION COMPLETE ===
echo.
echo Review the log files for detailed compilation results:
echo - compile_foundation.log
echo - compile_tests.log
