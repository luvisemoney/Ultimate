@echo off
REM ============================================================================
REM JAILBREAK COMPONENT 2: Security Framework Validation
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK COMPONENT 2: SECURITY FRAMEWORK
echo JailbreakSecurity.mqh Validation and Analysis
echo ===============================================================================
echo.

set "PROJECT_PATH=%~dp0"
set "SECURITY_FILE=%PROJECT_PATH%Include\Core\JailbreakSecurity.mqh"
set "ANALYSIS_LOG=%PROJECT_PATH%security_analysis.log"

echo Analyzing: %SECURITY_FILE%
echo Analysis log: %ANALYSIS_LOG%
echo.

REM Initialize analysis log
echo JAILBREAK SECURITY FRAMEWORK ANALYSIS - %date% %time% > "%ANALYSIS_LOG%"
echo =============================================================================== >> "%ANALYSIS_LOG%"

if not exist "%SECURITY_FILE%" (
    echo ✗ ERROR: Security framework file not found!
    echo ✗ Expected location: %SECURITY_FILE%
    echo ✗ ERROR: Security framework file not found! >> "%ANALYSIS_LOG%"
    pause
    exit /b 1
)

echo ✓ Security framework file found
echo ✓ Security framework file found >> "%ANALYSIS_LOG%"

REM Analyze security framework content
echo.
echo Analyzing security framework implementation...
echo Analyzing security framework implementation... >> "%ANALYSIS_LOG%"

REM Check for critical security methods
findstr /C:"ValidateAccountType" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Account validation method found
    echo ✓ Account validation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Account validation method missing
    echo ✗ Account validation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"ValidateAccountBalance" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Balance validation method found
    echo ✓ Balance validation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Balance validation method missing
    echo ✗ Balance validation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"ValidateMarginLevel" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Margin validation method found
    echo ✓ Margin validation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Margin validation method missing
    echo ✗ Margin validation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"ValidateRiskParameter" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Risk validation method found
    echo ✓ Risk validation method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Risk validation method missing
    echo ✗ Risk validation method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"CalculateSecurityHash" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Security hash method found
    echo ✓ Security hash method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Security hash method missing
    echo ✗ Security hash method missing >> "%ANALYSIS_LOG%"
)

REM Check for security constants
findstr /C:"SECURITY_HASH_SEED" "%SECURITY_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Security constants defined
    echo ✓ Security constants defined >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Security constants missing
    echo ✗ Security constants missing >> "%ANALYSIS_LOG%"
)

echo.
echo ===============================================================================
echo SECURITY FRAMEWORK ANALYSIS COMPLETE
echo ===============================================================================
echo ✓ Component 2 (Security Framework) validation completed
echo ✓ Analysis log saved to: %ANALYSIS_LOG%
echo.

echo Press any key to continue...
pause >nul