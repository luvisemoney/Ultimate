@echo off
REM ============================================================================
REM COMPILE_MASTER_CORRECTED.bat - JAILBREAK CORRECTED COMPILATION SYSTEM
REM ============================================================================
REM Purpose: MQL5-AWARE compilation with ACCURATE .ex5 verification
REM Author: Red Team Architecture Panel - FALSE POSITIVE CORRECTED
REM Version: 4.0 - ACCURATE VALIDATION EDITION
REM Date: %DATE%
REM ============================================================================
REM 
REM 💣 JAILBREAK FIXES FOR FALSE POSITIVES:
REM - Replaced unreliable ERRORLEVEL checking with .ex5 file verification
REM - Added pre-compilation .ex5 cleanup to ensure fresh results
REM - Implemented accurate success/failure detection
REM - Added detailed compilation output capture
REM ============================================================================

setlocal enabledelayedexpansion
set METAEDITOR="C:\Program Files\MetaTrader 5\MetaEditor64.exe"
set PROJECT_ROOT=%~dp0
set TIMESTAMP=%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

REM ============================================================================
REM PHASE 1: INITIALIZATION WITH ACCURATE VALIDATION
REM ============================================================================
echo.
echo ============================================================================
echo COMPILE_MASTER_CORRECTED.bat - ACCURATE VALIDATION SYSTEM v4.0
echo ============================================================================
echo Red Team Architecture: .ex5 Verification Based Compilation
echo Timestamp: %TIMESTAMP%
echo Project Root: %PROJECT_ROOT%
echo MetaEditor Path: %METAEDITOR%
echo ============================================================================

REM Create directory structure
if not exist "CompilationLogs" mkdir "CompilationLogs"
if not exist "ValidationLogs" mkdir "ValidationLogs"
if not exist "ArchitectureLogs" mkdir "ArchitectureLogs"

REM Initialize log files
set MASTER_LOG=CompilationLogs\CompilationReport_CORRECTED_%TIMESTAMP%.txt
set ERROR_LOG=CompilationLogs\ErrorReport_CORRECTED_%TIMESTAMP%.txt
set VALIDATION_LOG=ValidationLogs\ValidationReport_CORRECTED_%TIMESTAMP%.txt
set DETAILED_LOG=CompilationLogs\DetailedCompilation_%TIMESTAMP%.txt

echo ACCURATE COMPILATION VALIDATION STARTED: %DATE% %TIME% > %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%
echo CORRECTED LOGIC: .ex5 file verification instead of exit codes >> %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%
echo. >> %MASTER_LOG%

REM Verify MetaEditor exists
if not exist %METAEDITOR% (
    echo ERROR: MetaEditor not found at %METAEDITOR% >> %ERROR_LOG%
    echo ERROR: MetaEditor not found at %METAEDITOR%
    pause
    exit /b 1
)

echo MetaEditor verified: %METAEDITOR% >> %MASTER_LOG%

REM ============================================================================
REM PHASE 2: FILE CLASSIFICATION WITH CLEANUP
REM ============================================================================
echo.
echo ============================================================================
echo Phase 2: File Classification and Pre-Compilation Cleanup
echo ============================================================================

REM Count files
set TOTAL_MQ5_FILES=0
set TOTAL_MQH_FILES=0
set PRODUCTION_EAS=0

for /f %%i in ('cmd /c "dir /s /b *.mq5 2>nul | find /c /v """') do set TOTAL_MQ5_FILES=%%i
for /f %%i in ('cmd /c "dir /s /b *.mqh 2>nul | find /c /v """') do set TOTAL_MQH_FILES=%%i
for /f %%i in ('cmd /c "dir /s /b *.mq5 2>nul | findstr /v /i test | find /c /v """') do set PRODUCTION_EAS=%%i

set /a TEST_FILES=%TOTAL_MQ5_FILES% - %PRODUCTION_EAS%

echo FILE CLASSIFICATION: >> %MASTER_LOG%
echo   Compilable Files (.mq5): %TOTAL_MQ5_FILES% >> %MASTER_LOG%
echo   Include Files (.mqh): %TOTAL_MQH_FILES% >> %MASTER_LOG%
echo   Production EAs: %PRODUCTION_EAS% >> %MASTER_LOG%
echo   Test Files: %TEST_FILES% >> %MASTER_LOG%
echo. >> %MASTER_LOG%

REM Clean up existing .ex5 files for accurate testing
echo Cleaning up existing .ex5 files for accurate validation... >> %MASTER_LOG%
set INITIAL_EX5_COUNT=0
for /f %%i in ('powershell -c "(Get-ChildItem -Recurse -Filter '*.ex5').Count" 2^>nul') do set INITIAL_EX5_COUNT=%%i
echo Initial .ex5 files found: %INITIAL_EX5_COUNT% >> %MASTER_LOG%

REM Delete existing .ex5 files to ensure fresh compilation results
for /r . %%F in (*.ex5) do (
    echo Removing existing: %%F >> %MASTER_LOG%
    del "%%F" 2>nul
)

REM ============================================================================
REM PHASE 3: ACCURATE COMPILATION WITH .EX5 VERIFICATION
REM ============================================================================
echo.
echo ============================================================================
echo Phase 3: Accurate Compilation with .ex5 Verification
echo ============================================================================

REM Initialize counters
set TOTAL_COMPILATION_TARGETS=0
set SUCCESSFUL_COMPILATIONS=0
set FAILED_COMPILATIONS=0
set PRODUCTION_SUCCESS=0
set TEST_SUCCESS=0

echo ACCURATE COMPILATION STARTED: %DATE% %TIME% >> %MASTER_LOG%
echo VALIDATION METHOD: .ex5 file existence verification >> %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%

REM ============================================================================
REM CYCLE 1: PRODUCTION EA COMPILATION WITH ACCURATE VALIDATION
REM ============================================================================
echo.
echo --- Cycle 1: Production EA Compilation (Accurate Validation) ---
echo Cycle 1: Production EA Compilation >> %MASTER_LOG%

REM Compile production EAs
set PRODUCTION_TARGETS=LiveEA\LiveEA_MLEnhanced.mq5 PaperEA\PaperEA_MLEnhanced.mq5
for %%F in (%PRODUCTION_TARGETS%) do (
    if exist "%%F" (
        echo Compiling PRODUCTION EA: %%F
        echo Compiling PRODUCTION EA: %%F >> %MASTER_LOG%
        
        REM Get expected .ex5 file path
        set "EX5_FILE=%%~dpnF.ex5"
        
        REM Ensure .ex5 doesn't exist before compilation
        if exist "!EX5_FILE!" (
            del "!EX5_FILE!" 2>nul
            echo Pre-deleted existing: !EX5_FILE! >> %DETAILED_LOG%
        )
        
        REM Compile with detailed output
        echo Executing: %METAEDITOR% /compile:"%%F" /log >> %DETAILED_LOG%
        %METAEDITOR% /compile:"%%F" /log >> %DETAILED_LOG% 2>&1
        set COMPILE_EXIT_CODE=!ERRORLEVEL!
        
        REM Wait a moment for file system to update
        timeout /t 1 /nobreak >nul 2>&1
        
        REM Check if .ex5 file was actually created (ACCURATE VALIDATION)
        if exist "!EX5_FILE!" (
            echo ✅ SUCCESS: %%F (Verified .ex5 created) >> %MASTER_LOG%
            echo ✅ SUCCESS: %%F - .ex5 file verified
            set /a SUCCESSFUL_COMPILATIONS+=1
            set /a PRODUCTION_SUCCESS+=1
        ) else (
            echo ❌ FAILED: %%F (No .ex5 file generated) >> %ERROR_LOG%
            echo ❌ FAILED: %%F - No .ex5 file generated
            echo Exit Code: !COMPILE_EXIT_CODE! >> %ERROR_LOG%
            set /a FAILED_COMPILATIONS+=1
        )
        set /a TOTAL_COMPILATION_TARGETS+=1
    ) else (
        echo ⚠️ WARNING: Production EA not found: %%F >> %ERROR_LOG%
    )
)

REM ============================================================================
REM CYCLE 2: TEST COMPILATION WITH ACCURATE VALIDATION
REM ============================================================================
echo.
echo --- Cycle 2: Test Suite Compilation (Accurate Validation) ---
echo Cycle 2: Test Suite Compilation >> %MASTER_LOG%

REM Compile all .mq5 test files
for /r . %%F in (*.mq5) do (
    set "FILEPATH=%%F"
    set "FILENAME=%%~nxF"
    
    REM Skip production EAs (already compiled)
    echo !FILENAME! | findstr /i "LiveEA_MLEnhanced PaperEA_MLEnhanced" >nul
    if !ERRORLEVEL! NEQ 0 (
        echo Compiling TEST: %%F
        echo Compiling TEST: %%F >> %MASTER_LOG%
        
        REM Get expected .ex5 file path
        set "EX5_FILE=%%~dpnF.ex5"
        
        REM Ensure .ex5 doesn't exist before compilation
        if exist "!EX5_FILE!" (
            del "!EX5_FILE!" 2>nul
            echo Pre-deleted existing: !EX5_FILE! >> %DETAILED_LOG%
        )
        
        REM Compile with detailed output
        echo Executing: %METAEDITOR% /compile:"%%F" /log >> %DETAILED_LOG%
        %METAEDITOR% /compile:"%%F" /log >> %DETAILED_LOG% 2>&1
        set COMPILE_EXIT_CODE=!ERRORLEVEL!
        
        REM Wait a moment for file system to update
        timeout /t 1 /nobreak >nul 2>&1
        
        REM Check if .ex5 file was actually created (ACCURATE VALIDATION)
        if exist "!EX5_FILE!" (
            echo ✅ SUCCESS: %%F (Verified .ex5 created) >> %MASTER_LOG%
            set /a SUCCESSFUL_COMPILATIONS+=1
            set /a TEST_SUCCESS+=1
        ) else (
            echo ❌ FAILED: %%F (No .ex5 file generated) >> %ERROR_LOG%
            echo ❌ FAILED: %%F - No .ex5 file generated
            echo Exit Code: !COMPILE_EXIT_CODE! >> %ERROR_LOG%
            set /a FAILED_COMPILATIONS+=1
        )
        set /a TOTAL_COMPILATION_TARGETS+=1
    )
)

REM ============================================================================
REM PHASE 4: ACCURATE REPORTING
REM ============================================================================
echo.
echo ============================================================================
echo Phase 4: Accurate Compilation Reporting
echo ============================================================================

REM Count actual .ex5 files generated
set ACTUAL_EX5_COUNT=0
for /f %%i in ('powershell -c "(Get-ChildItem -Recurse -Filter '*.ex5').Count" 2^>nul') do set ACTUAL_EX5_COUNT=%%i

REM Calculate accurate success rates
set COMPILATION_SUCCESS_RATE=0
if %TOTAL_COMPILATION_TARGETS% GTR 0 (
    set /a TEMP_CALC=%SUCCESSFUL_COMPILATIONS% * 100
    set /a COMPILATION_SUCCESS_RATE=!TEMP_CALC! / %TOTAL_COMPILATION_TARGETS%
)

echo. >> %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%
echo ACCURATE COMPILATION SUMMARY >> %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%
echo COMPILATION TARGETS: >> %MASTER_LOG%
echo   Total Targets: %TOTAL_COMPILATION_TARGETS% >> %MASTER_LOG%
echo   Successful: %SUCCESSFUL_COMPILATIONS% >> %MASTER_LOG%
echo   Failed: %FAILED_COMPILATIONS% >> %MASTER_LOG%
echo   Success Rate: %COMPILATION_SUCCESS_RATE%%% >> %MASTER_LOG%
echo. >> %MASTER_LOG%
echo VERIFICATION RESULTS: >> %MASTER_LOG%
echo   Actual .ex5 Files Generated: %ACTUAL_EX5_COUNT% >> %MASTER_LOG%
echo   Expected .ex5 Files: %SUCCESSFUL_COMPILATIONS% >> %MASTER_LOG%
echo   Verification Match: %ACTUAL_EX5_COUNT%/%SUCCESSFUL_COMPILATIONS% >> %MASTER_LOG%
echo. >> %MASTER_LOG%
echo PRODUCTION STATUS: >> %MASTER_LOG%
echo   Production EAs: %PRODUCTION_SUCCESS%/%PRODUCTION_EAS% >> %MASTER_LOG%
echo   Test Files: %TEST_SUCCESS%/%TEST_FILES% >> %MASTER_LOG%
echo ============================================================================ >> %MASTER_LOG%

REM Final report
echo.
echo ============================================================================
echo ACCURATE COMPILATION COMPLETE
echo ============================================================================
echo COMPILATION STATISTICS (VERIFIED):
echo   Total Targets: %TOTAL_COMPILATION_TARGETS%
echo   Successful: %SUCCESSFUL_COMPILATIONS%
echo   Failed: %FAILED_COMPILATIONS%
echo   Success Rate: %COMPILATION_SUCCESS_RATE%%%
echo.
echo VERIFICATION RESULTS:
echo   Actual .ex5 Files: %ACTUAL_EX5_COUNT%
echo   Expected .ex5 Files: %SUCCESSFUL_COMPILATIONS%
echo   Verification Accuracy: %ACTUAL_EX5_COUNT%/%SUCCESSFUL_COMPILATIONS%
echo.
echo PRODUCTION STATUS:
echo   Production EAs: %PRODUCTION_SUCCESS%/%PRODUCTION_EAS%
echo   Test Files: %TEST_SUCCESS%/%TEST_FILES%
echo.
echo CORRECTED VALIDATION:
echo   - Replaced unreliable exit codes with .ex5 verification
echo   - Pre-compilation cleanup ensures accurate results
echo   - Detailed logging captures actual compilation output
echo.
echo Log Files:
echo   - Master Log: %MASTER_LOG%
echo   - Error Log: %ERROR_LOG%
echo   - Detailed Log: %DETAILED_LOG%
echo.

if %FAILED_COMPILATIONS% GTR 0 (
    echo WARNING: %FAILED_COMPILATIONS% compilation failures detected.
    echo Review error log: %ERROR_LOG%
    echo Review detailed log: %DETAILED_LOG%
    echo.
    echo CORRECTED INSIGHT: Previous false positives eliminated through .ex5 verification.
) else (
    echo SUCCESS: All compilation targets compiled successfully!
    echo Verification: %ACTUAL_EX5_COUNT% .ex5 files generated as expected.
    echo.
    echo VALIDATION SUCCESS: Accurate compilation detection achieved.
)

echo ============================================================================
echo CORRECTED COMPILE_MASTER execution completed.
echo ============================================================================

if %FAILED_COMPILATIONS% GTR 0 (
    pause
    exit /b 1
) else (
    pause
    exit /b 0
)

endlocal