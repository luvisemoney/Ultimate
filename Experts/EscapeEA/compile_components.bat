@echo off
setlocal enabledelayedexpansion

echo ================================================
echo        Compiling EscapeEA - Individual Components
echo ================================================
echo.

echo [1/4] Compiling PaperEA...
if exist "PaperEA\compile.bat" (
    cd PaperEA
    call compile.bat
    cd ..
    if exist "PaperEA\PaperEA.ex5" (
        echo [OK] PaperEA compiled successfully
    ) else (
        echo [ERROR] PaperEA compilation failed
        set "error=1"
    )
) else (
    echo [WARNING] PaperEA compile script not found
)
echo.

echo [2/4] Compiling LiveEA...
if exist "LiveEA\compile.bat" (
    cd LiveEA
    call compile.bat
    cd ..
    if exist "LiveEA\LiveEA.ex5" (
        echo [OK] LiveEA compiled successfully
    ) else (
        echo [ERROR] LiveEA compilation failed
        set "error=1"
    )
) else (
    echo [WARNING] LiveEA compile script not found
)
echo.

echo [3/4] Compiling Tests...
if exist "Tests\compile.bat" (
    cd Tests
    call compile.bat
    cd ..
    if exist "Tests\RunTestsScript.ex5" (
        echo [OK] Tests compiled successfully
    ) else (
        echo [ERROR] Tests compilation failed
        set "error=1"
    )
) else (
    echo [WARNING] Tests compile script not found
)
echo.

echo [4/4] Compiling Learning Module...
if exist "Include\Learning\compile.bat" (
    cd "Include\Learning"
    call compile.bat
    cd ..\..
    if exist "Include\Learning\*.ex5" (
        echo [OK] Learning module compiled successfully
    ) else (
        echo [ERROR] Learning module compilation failed
        set "error=1"
    )
) else (
    echo [WARNING] Learning module compile script not found
)
echo.

echo ================================================
if defined error (
    echo [RESULT] Some components failed to compile
    exit /b 1
) else (
    echo [RESULT] All components compiled successfully
    exit /b 0
)
