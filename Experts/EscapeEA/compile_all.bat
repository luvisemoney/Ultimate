@echo off
setlocal enabledelayedexpansion

echo ================================================
echo        Compiling EscapeEA - All Components
echo ================================================
echo.

set "error_count=0"
set "success_count=0"
set "warning_count=0"
set "start_time=%time%"

echo [%time%] Starting compilation...
echo.

:: Compile Core Components
call :CompileInclude "Include" "Common"
call :CompileInclude "Include" "Core"
call :CompileInclude "Include" "Learning"
call :CompileInclude "Include" "Communication"
call :CompileInclude "Include" "Utils"

:: Compile PaperEA
call :CompileComponent "PaperEA" "PaperEA.mq5"

:: Compile LiveEA
call :CompileComponent "LiveEA" "LiveEA.mq5"

:: Compile Tests
call :CompileComponent "Tests" "RunTests.mq5"

:: Compile Scripts
call :CompileScript "Scripts/EscapeEA" "ValidateUIAndLogging.mq5"

:: Compile Indicators (if any)
if exist "Indicators\*.mq5" (
    echo.
    echo ================================================
    echo        Compiling Indicators
    echo ================================================
    for %%f in (Indicators\*.mq5) do (
        call :CompileFile "Indicators" "%%~nxf"
    )
)

set "end_time=%time%"

echo.
echo ================================================
echo                  Summary
echo ================================================
echo Start Time: %start_time%
echo End Time:   %end_time%
echo.
echo Successfully compiled: %success_count% component(s)
if %warning_count% GTR 0 (
    echo Warnings: %warning_count%
)
if %error_count% GTR 0 (
    echo Errors: %error_count%
)

if %error_count% EQU 0 (
    echo.
    echo All components compiled successfully! ^(with %warning_count% warning^(s^)^)
) else (
    echo.
    echo %error_count% component(s) had errors during compilation.
)
echo ================================================

if "%1"=="" pause
exit /b %error_count%

:CompileComponent
set "component=%~1"
set "source_file=%~2"
set "component_path=%~dp0%component%"
set "compile_script=%component_path%\compile.bat"

if exist "%component_path%" (
    echo.
    echo ================================================
    echo        Compiling %component%
    echo ================================================
    
    if exist "%compile_script%" (
        pushd "%component_path%"
        call compile.bat
        if errorlevel 1 (
            echo Error: %component% compilation failed.
            set /a error_count+=1
        ) else (
            set /a success_count+=1
        )
        popd
    ) else (
        echo Warning: No compile script found for %component%
    )
) else (
    echo Warning: %component% directory not found.
)

exit /b
