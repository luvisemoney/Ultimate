@echo off
setlocal enabledelayedexpansion

:: Set colors
set "RED=31"
set "GREEN=32"
set "YELLOW=33"
set "NC=0"

:: Function to print colored text
:colorEcho
set text=%~1
set color=!%~2!
echo [%time%] ^<ESC^>[!color!m!text!^<ESC^>[%NC%m
exit /b 0

echo.
echo ================================================
echo        ESCAPEEA COMPILATION SCRIPT
echo ================================================
echo.

set "error_count=0"
set "success_count=0"

echo [1/4] Compiling PaperEA...
if exist "PaperEA\compile.bat" (
    cd PaperEA
    call compile.bat
    cd ..
    if exist "PaperEA\PaperEA.ex5" (
        echo [%time%] PaperEA compiled successfully
        set /a success_count+=1
    ) else (
        echo [%time%] Error: PaperEA compilation failed
        set /a error_count+=1
    )
) else (
    echo [%time%] Warning: PaperEA compile script not found
)

echo.
echo [2/4] Compiling LiveEA...
if exist "LiveEA\compile.bat" (
    cd LiveEA
    call compile.bat
    cd ..
    if exist "LiveEA\LiveEA.ex5" (
        echo [%time%] LiveEA compiled successfully
        set /a success_count+=1
    ) else (
        echo [%time%] Error: LiveEA compilation failed
        set /a error_count+=1
    )
) else (
    echo [%time%] Warning: LiveEA compile script not found
)

echo.
echo [3/4] Compiling Tests...
if exist "Tests\compile.bat" (
    cd Tests
    call compile.bat
    cd ..
    if exist "Tests\RunTestsScript.ex5" (
        echo [%time%] Tests compiled successfully
        set /a success_count+=1
    ) else (
        echo [%time%] Error: Tests compilation failed
        set /a error_count+=1
    )
) else (
    echo [%time%] Warning: Tests compile script not found
)

echo.
echo [4/4] Compiling Learning Module...
if exist "Include\Learning\compile.bat" (
    cd "Include\Learning"
    call compile.bat
    cd ..\..
    if exist "Include\Learning\*.ex5" (
        echo [%time%] Learning module compiled successfully
        set /a success_count+=1
    ) else (
        echo [%time%] Error: Learning module compilation failed
        set /a error_count+=1
    )
) else (
    echo [%time%] Warning: Learning module compile script not found
)

echo.
echo ================================================
if %error_count% EQU 0 (
    echo [%time%] ALL COMPONENTS COMPILED SUCCESSFULLY!
) else (
    echo [%time%] %success_count% of 4 components compiled successfully
    echo [%time%] %error_count% components had errors
)
echo ================================================

pause
