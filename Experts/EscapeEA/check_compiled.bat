@echo off
echo Checking for compiled components...
echo =================================

echo [1/4] Checking PaperEA...
if exist "PaperEA\PaperEA.ex5" (
    echo   - PaperEA.ex5 exists
) else (
    echo   - PaperEA.ex5 NOT FOUND
)

echo [2/4] Checking LiveEA...
if exist "LiveEA\LiveEA.ex5" (
    echo   - LiveEA.ex5 exists
) else (
    echo   - LiveEA.ex5 NOT FOUND
)

echo [3/4] Checking Tests...
if exist "Tests\RunTestsScript.ex5" (
    echo   - RunTestsScript.ex5 exists
) else (
    echo   - RunTestsScript.ex5 NOT FOUND
)

echo [4/4] Checking Learning Module...
dir /b "Include\Learning\*.ex5" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   - No .ex5 files found in Learning module
)

echo =================================
pause
