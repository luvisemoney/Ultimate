@echo off
REM Compile DualEA_Foundation.mq5 using MetaEditor
setlocal
set MQ5_FILE=DualEA_Foundation.mq5
set LOG_FILE=compile_DualEA_Foundation.log
REM Update the path to MetaEditor.exe as needed
set METAEDITOR_PATH="C:\Program Files\MetaTrader 5\MetaEditor64.exe"

%METAEDITOR_PATH% /compile:%MQ5_FILE% /log:%LOG_FILE%
endlocal
