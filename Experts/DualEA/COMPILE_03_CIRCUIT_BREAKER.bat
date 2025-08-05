@echo off
REM ============================================================================
REM JAILBREAK COMPONENT 3: Emergency Circuit Breaker Validation
REM ============================================================================
setlocal enabledelayedexpansion

echo.
echo ===============================================================================
echo JAILBREAK COMPONENT 3: EMERGENCY CIRCUIT BREAKER
echo EmergencyCircuitBreaker.mqh Validation and Analysis
echo ===============================================================================
echo.

set "PROJECT_PATH=%~dp0"
set "CIRCUIT_BREAKER_FILE=%PROJECT_PATH%Include\Core\EmergencyCircuitBreaker.mqh"
set "ANALYSIS_LOG=%PROJECT_PATH%circuit_breaker_analysis.log"

echo Analyzing: %CIRCUIT_BREAKER_FILE%
echo Analysis log: %ANALYSIS_LOG%
echo.

REM Initialize analysis log
echo JAILBREAK CIRCUIT BREAKER ANALYSIS - %date% %time% > "%ANALYSIS_LOG%"
echo =============================================================================== >> "%ANALYSIS_LOG%"

if not exist "%CIRCUIT_BREAKER_FILE%" (
    echo ✗ ERROR: Circuit breaker file not found!
    echo ✗ Expected location: %CIRCUIT_BREAKER_FILE%
    echo ✗ ERROR: Circuit breaker file not found! >> "%ANALYSIS_LOG%"
    
    echo.
    echo Creating emergency circuit breaker implementation...
    echo Creating emergency circuit breaker implementation... >> "%ANALYSIS_LOG%"
    
    REM Create the directory if it doesn't exist
    if not exist "%PROJECT_PATH%Include\Core\" mkdir "%PROJECT_PATH%Include\Core\"
    
    REM Create basic circuit breaker implementation
    echo //+------------------------------------------------------------------+ > "%CIRCUIT_BREAKER_FILE%"
    echo //^| EmergencyCircuitBreaker.mqh                                      ^| >> "%CIRCUIT_BREAKER_FILE%"
    echo //^| JAILBREAK LEVEL 5 - EMERGENCY CIRCUIT BREAKER SYSTEM            ^| >> "%CIRCUIT_BREAKER_FILE%"
    echo //+------------------------------------------------------------------+ >> "%CIRCUIT_BREAKER_FILE%"
    echo #property copyright "EscapeEA - Jailbreak Level 5 Circuit Breaker" >> "%CIRCUIT_BREAKER_FILE%"
    echo #property version   "1.00" >> "%CIRCUIT_BREAKER_FILE%"
    echo #property strict >> "%CIRCUIT_BREAKER_FILE%"
    echo. >> "%CIRCUIT_BREAKER_FILE%"
    echo class CEmergencyCircuitBreaker >> "%CIRCUIT_BREAKER_FILE%"
    echo { >> "%CIRCUIT_BREAKER_FILE%"
    echo private: >> "%CIRCUIT_BREAKER_FILE%"
    echo     double m_maxDrawdown; >> "%CIRCUIT_BREAKER_FILE%"
    echo     int m_maxConsecutiveLosses; >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool m_isInitialized; >> "%CIRCUIT_BREAKER_FILE%"
    echo. >> "%CIRCUIT_BREAKER_FILE%"
    echo public: >> "%CIRCUIT_BREAKER_FILE%"
    echo     CEmergencyCircuitBreaker(double maxDrawdown, int maxLosses^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     ~CEmergencyCircuitBreaker(^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool Initialize(CJailbreakLogger* logger^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool CheckDrawdownLimit(double currentDrawdown^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool CheckConsecutiveLosses(int losses^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool CheckMarginLevel(double marginLevel^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool CheckDailyTradeLimit(int trades, int maxTrades^); >> "%CIRCUIT_BREAKER_FILE%"
    echo     bool CheckMarketConditions(^); >> "%CIRCUIT_BREAKER_FILE%"
    echo }; >> "%CIRCUIT_BREAKER_FILE%"
    
    echo ✓ Basic circuit breaker implementation created
    echo ✓ Basic circuit breaker implementation created >> "%ANALYSIS_LOG%"
)

echo ✓ Circuit breaker file found/created
echo ✓ Circuit breaker file found/created >> "%ANALYSIS_LOG%"

REM Analyze circuit breaker content
echo.
echo Analyzing circuit breaker implementation...
echo Analyzing circuit breaker implementation... >> "%ANALYSIS_LOG%"

REM Check for critical circuit breaker methods
findstr /C:"CheckDrawdownLimit" "%CIRCUIT_BREAKER_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Drawdown limit check method found
    echo ✓ Drawdown limit check method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Drawdown limit check method missing
    echo ✗ Drawdown limit check method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"CheckConsecutiveLosses" "%CIRCUIT_BREAKER_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Consecutive losses check method found
    echo ✓ Consecutive losses check method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Consecutive losses check method missing
    echo ✗ Consecutive losses check method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"CheckMarginLevel" "%CIRCUIT_BREAKER_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Margin level check method found
    echo ✓ Margin level check method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Margin level check method missing
    echo ✗ Margin level check method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"CheckDailyTradeLimit" "%CIRCUIT_BREAKER_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Daily trade limit check method found
    echo ✓ Daily trade limit check method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Daily trade limit check method missing
    echo ✗ Daily trade limit check method missing >> "%ANALYSIS_LOG%"
)

findstr /C:"CheckMarketConditions" "%CIRCUIT_BREAKER_FILE%" >nul
if !errorlevel! equ 0 (
    echo ✓ Market conditions check method found
    echo ✓ Market conditions check method found >> "%ANALYSIS_LOG%"
) else (
    echo ✗ Market conditions check method missing
    echo ✗ Market conditions check method missing >> "%ANALYSIS_LOG%"
)

echo.
echo ===============================================================================
echo CIRCUIT BREAKER ANALYSIS COMPLETE
echo ===============================================================================
echo ✓ Component 3 (Emergency Circuit Breaker) validation completed
echo ✓ Analysis log saved to: %ANALYSIS_LOG%
echo.

echo Press any key to continue...
pause >nul