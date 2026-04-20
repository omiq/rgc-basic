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
REM
REM Uses goto-based flow (no parenthesized if/else blocks) because cmd.exe
REM parser is sensitive to parentheses in command output — an earlier
REM version lost control after `git clone` printed the detached-HEAD
REM advice and never reached the patch/build steps.

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
REM Step 1: fetch raylib source if missing, else retag
REM -------------------------------------------------------------
if exist "%RAYLIB_DIR%\.git" goto :have_raylib

echo build-raylib-native: cloning raylib %RAYLIB_VERSION% into %RAYLIB_DIR%
if exist "%RAYLIB_DIR%" rmdir /S /Q "%RAYLIB_DIR%"
REM -c core.autocrlf=input: keep LF line endings on Windows so the LF-format
REM patches in patches/*.patch apply cleanly. Default Git-for-Windows has
REM core.autocrlf=true, which converts .c/.h to CRLF at checkout and causes
REM `git apply` to silently fail the whitespace check.
git -c core.autocrlf=input clone --depth 1 --branch %RAYLIB_VERSION% https://github.com/raysan5/raylib.git "%RAYLIB_DIR%"
if errorlevel 1 goto :fail
goto :patches

:have_raylib
set "CURRENT_TAG="
for /f "delims=" %%t in ('git -C "%RAYLIB_DIR%" describe --tags --exact-match 2^>nul') do set "CURRENT_TAG=%%t"
if "!CURRENT_TAG!"=="%RAYLIB_VERSION%" goto :patches
echo build-raylib-native: switching raylib checkout to %RAYLIB_VERSION%
git -C "%RAYLIB_DIR%" fetch --depth 1 origin "refs/tags/%RAYLIB_VERSION%:refs/tags/%RAYLIB_VERSION%"
if errorlevel 1 goto :fail
git -C "%RAYLIB_DIR%" checkout -f "tags/%RAYLIB_VERSION%"
if errorlevel 1 goto :fail
set RAYLIB_FORCE=1

:patches
REM -------------------------------------------------------------
REM Step 2: apply patches (same set as web + .sh counterpart)
REM -------------------------------------------------------------
if not exist "%PATCH_DIR%" goto :check_build
for %%p in ("%PATCH_DIR%\*.patch") do call :apply_one "%%p"
if errorlevel 1 goto :fail

:check_build
REM -------------------------------------------------------------
REM Step 3: build libraylib.a for PLATFORM_DESKTOP (mingw32-make)
REM -------------------------------------------------------------
if not exist "%LIBRAYLIB%" goto :build
if "%RAYLIB_FORCE%"=="1" goto :build
echo build-raylib-native: %LIBRAYLIB% already built (set RAYLIB_FORCE=1 to rebuild)
exit /B 0

:build
echo build-raylib-native: building raylib PLATFORM_DESKTOP
pushd "%RAYLIB_DIR%\src"
mingw32-make clean >nul 2>&1
mingw32-make PLATFORM=PLATFORM_DESKTOP -B
if errorlevel 1 goto :build_fail
popd

if not exist "%LIBRAYLIB%" goto :missing_lib

echo build-raylib-native: OK
echo   Library: %LIBRAYLIB%
echo   Headers: %RAYLIB_DIR%\src\raylib.h raymath.h rlgl.h
exit /B 0

:apply_one
set "p=%~1"
set "pname=%~nx1"
REM Probe forward-apply first. If it applies, do it. If it doesn't,
REM probe reverse-apply — already-applied patches report success here
REM and we can skip. Errors go to stderr (unlike the prior version that
REM swallowed them with `>nul 2>&1`) so CRLF/whitespace failures are
REM visible.
git -C "%RAYLIB_DIR%" apply --check "%p%" >nul 2>&1
if not errorlevel 1 goto :apply_do
git -C "%RAYLIB_DIR%" apply --reverse --check "%p%" >nul 2>&1
if not errorlevel 1 (
    echo build-raylib-native: patch %pname% already applied, skipping
    exit /B 0
)
echo build-raylib-native: ERROR patch %pname% no longer applies cleanly against raylib %RAYLIB_VERSION%
echo   git apply output:
git -C "%RAYLIB_DIR%" apply --check "%p%"
echo   Rebase %p% and re-run. See patches\README.md.
exit /B 1

:apply_do
echo build-raylib-native: applying %pname%
git -C "%RAYLIB_DIR%" apply "%p%"
if errorlevel 1 (
    echo build-raylib-native: ERROR applying %pname% failed
    exit /B 1
)
set RAYLIB_FORCE=1
exit /B 0

:build_fail
popd
goto :fail

:missing_lib
echo build-raylib-native: ERROR build completed but %LIBRAYLIB% missing
goto :fail

:fail
echo build-raylib-native: FAILED
exit /B 1
