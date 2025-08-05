@echo off
REM Compile PaperEA_MLEnhanced.mq5 using MetaEditor CLI

SET METAEDITOR_PATH="C:\Program Files\MetaTrader 5\metaeditor.exe"
SET EA_PATH="c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\EscapeEA\PaperEA\PaperEA_MLEnhanced.mq5"

%METAEDITOR_PATH% /compile:%EA_PATH%

IF %ERRORLEVEL% EQU 0 (
    echo Compile succeeded.
) ELSE (
    echo Compile failed with errorlevel %ERRORLEVEL%.
)
pause
