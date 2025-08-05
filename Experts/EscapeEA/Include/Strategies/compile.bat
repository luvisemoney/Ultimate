@echo off
setlocal enabledelayedexpansion

:compile_loop
    echo Compiling AdvancedStrategy.mqh...
    "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0AdvancedStrategy.mqh" /log:"%~dp0compile_output.log"
    
    echo.
    echo Compilation log:
    type "%~dp0compile_output.log"
    
    set "has_errors=0"
    set "has_warnings=0"
    
    findstr /i "error" "%~dp0compile_output.log" >nul && set has_errors=1
    findstr /i "warning" "%~dp0compile_output.log" >nul && set has_warnings=1
    
    if "!has_errors!"=="0" (
        if "!has_warnings!"=="0" (
            echo.
            echo ===================================================
            echo COMPILATION SUCCESSFUL - No errors or warnings found
            echo ===================================================
            pause
            exit /b 0
        ) else (
            echo.
            echo ===================================================
            echo WARNING: Compilation has warnings but no errors
            echo ===================================================
            choice /t 3 /d y /m "Press any key to continue or wait 3 seconds to recompile..."
            if errorlevel 2 (
                exit /b 0
            )
        )
    ) else (
        echo.
        echo ===================================================
        echo ERRORS FOUND - Recompiling...
        echo ===================================================
        timeout /t 2 >nul
    )
    
    cls
goto :compile_loop
