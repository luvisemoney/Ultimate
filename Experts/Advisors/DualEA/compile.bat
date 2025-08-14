@echo off
REM Batch script to compile the PaperEA expert advisor.
REM This script checks the compiler log for success, not the exit code.

set METAEDITOR_PATH="C:\Program Files\MetaTrader 5\MetaEditor64.exe"
set SOURCE_FILE="c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\DualEA\PaperEA\PaperEA.mq5"
set LOG_FILE="c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\DualEA\PaperEA\PaperEA.log"

echo Compiling %SOURCE_FILE%...
REM Use start /wait to ensure the script pauses until the compiler is finished.
start "" /wait %METAEDITOR_PATH% /compile:%SOURCE_FILE% /log > nul

REM Use PowerShell to check the log file for the success message, as it handles file encodings better.
powershell -Command "if (Get-Content %LOG_FILE% | Select-String -Pattern ' 0 errors,') { exit 0 } else { exit 1 }"

if %errorlevel% neq 0 (
    echo. 
    echo ==================================================
    echo               COMPILATION FAILED
    echo ==================================================
    echo See %LOG_FILE% for details.
    echo.
    exit /b 1
) else (
    echo. 
    echo ==================================================
    echo             COMPILATION SUCCESSFUL
    echo ==================================================
    echo.
)
