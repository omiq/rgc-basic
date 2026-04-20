@echo off
REM Fetch + build raylib for the native Windows (MinGW) target.
REM Mirror of scripts/build-raylib-native.sh for POSIX. Windows mingw32-make
REM can't invoke .sh recipes without sh.exe on PATH, so the Makefile picks
REM this .cmd when OS=Windows_NT.
REM
REM Output:
REM   third_party\raylib-native\src\libraylib.a
REM
REM Requirements:
REM   - git, mingw32-make, gcc (MinGW-w64) on PATH.
REM
REM Env vars:
REM   RAYLIB_VERSION   git tag (default: 5.5)
REM   RAYLIB_FORCE     1 = force clean rebuild

setlocal enabledelayedexpansion

if "%RAYLIB_VERSION%"=="" set RAYLIB_VERSION=5.5
if "%RAYLIB_FORCE%"=="" set RAYLIB_FORCE=0

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"
popd

set "THIRD_PARTY=%REPO_ROOT%\third_party"
set "RAYLIB_DIR=%THIRD_PARTY%\raylib-native"
set "LIBRAYLIB=%RAYLIB_DIR%\src\libraylib.a"
set "PATCH_DIR=%REPO_ROOT%\patches"

if not exist "%THIRD_PARTY%" mkdir "%THIRD_PARTY%"

REM -------------------------------------------------------------
REM Step 1: fetch or retag raylib source
REM -------------------------------------------------------------
if not exist "%RAYLIB_DIR%\.git" (
    echo build-raylib-native: cloning raylib %RAYLIB_VERSION% into %RAYLIB_DIR%
    if exist "%RAYLIB_DIR%" rmdir /S /Q "%RAYLIB_DIR%"
    git clone --depth 1 --branch %RAYLIB_VERSION% https://github.com/raysan5/raylib.git "%RAYLIB_DIR%"
    if errorlevel 1 goto :fail
) else (
    for /f "delims=" %%t in ('git -C "%RAYLIB_DIR%" describe --tags --exact-match 2^>nul') do set "CURRENT_TAG=%%t"
    if not "!CURRENT_TAG!"=="%RAYLIB_VERSION%" (
        echo build-raylib-native: switching raylib checkout to %RAYLIB_VERSION%
        git -C "%RAYLIB_DIR%" fetch --depth 1 origin "refs/tags/%RAYLIB_VERSION%:refs/tags/%RAYLIB_VERSION%"
        git -C "%RAYLIB_DIR%" checkout -f "tags/%RAYLIB_VERSION%"
        if errorlevel 1 goto :fail
        set RAYLIB_FORCE=1
    )
)

REM -------------------------------------------------------------
REM Step 2: apply patches (same set as web + .sh counterpart)
REM -------------------------------------------------------------
if exist "%PATCH_DIR%" (
    for %%p in ("%PATCH_DIR%\*.patch") do (
        git -C "%RAYLIB_DIR%" apply --reverse --check "%%p" >nul 2>&1
        if errorlevel 1 (
            git -C "%RAYLIB_DIR%" apply --check "%%p" >nul 2>&1
            if errorlevel 1 (
                echo build-raylib-native: ERROR patch %%~nxp no longer applies cleanly against raylib %RAYLIB_VERSION%
                echo   Rebase %%p and re-run. See patches\README.md.
                goto :fail
            ) else (
                echo build-raylib-native: applying %%~nxp
                git -C "%RAYLIB_DIR%" apply "%%p"
                if errorlevel 1 goto :fail
                set RAYLIB_FORCE=1
            )
        ) else (
            echo build-raylib-native: patch %%~nxp already applied, skipping
        )
    )
)

REM -------------------------------------------------------------
REM Step 3: build libraylib.a for PLATFORM_DESKTOP (mingw32-make)
REM -------------------------------------------------------------
if exist "%LIBRAYLIB%" if not "%RAYLIB_FORCE%"=="1" (
    echo build-raylib-native: %LIBRAYLIB% already built (set RAYLIB_FORCE=1 to rebuild)
    exit /B 0
)

echo build-raylib-native: building raylib PLATFORM_DESKTOP
pushd "%RAYLIB_DIR%\src"
mingw32-make clean >nul 2>&1
mingw32-make PLATFORM=PLATFORM_DESKTOP -B
if errorlevel 1 (
    popd
    goto :fail
)
popd

if not exist "%LIBRAYLIB%" (
    echo build-raylib-native: ERROR build completed but %LIBRAYLIB% missing
    goto :fail
)

echo build-raylib-native: OK
echo   Library: %LIBRAYLIB%
echo   Headers: %RAYLIB_DIR%\src\raylib.h raymath.h rlgl.h
exit /B 0

:fail
echo build-raylib-native: FAILED
exit /B 1
