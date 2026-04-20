#!/bin/sh
# Fetch + build raylib for the native desktop target (PLATFORM_DESKTOP).
#
# Output:
#   third_party/raylib-native/src/libraylib.a
#   third_party/raylib-native/src/*.h
#
# These artefacts are gitignored. Re-run this script after bumping
# RAYLIB_VERSION or after `rm -rf third_party/raylib-native/`. The
# Makefile target `basic-gfx` depends on libraylib.a existing at the
# path above.
#
# Why build raylib from source for native too?
#   The system raylib installed via Homebrew / MinGW / apt is built
#   without the RGC-BASIC patches. In particular,
#   patches/raudio_mod_skip_max_samples.patch is required to keep
#   LoadMusicStream() from blocking for seconds while it simulates
#   the whole .mod song to compute frameCount. Without the patch the
#   interpreter thread hangs inside LOADMUSIC and keypresses queue
#   up unanswered. See CHANGELOG.md "MOD load freeze fix".
#
# Requirements:
#   - cc, make, git, standard POSIX shell.
#   - Platform-specific raylib build deps (e.g. libx11-dev on Linux,
#     xcode-select --install on macOS, mingw-w64 + make on Windows
#     inside MSYS2).
#
# Env vars:
#   RAYLIB_VERSION   git tag to check out (default: 5.5)
#   RAYLIB_FORCE     set to 1 to force a clean rebuild

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RAYLIB_VERSION="${RAYLIB_VERSION:-5.5}"
RAYLIB_FORCE="${RAYLIB_FORCE:-0}"

THIRD_PARTY="$REPO_ROOT/third_party"
RAYLIB_DIR="$THIRD_PARTY/raylib-native"
LIBRAYLIB="$RAYLIB_DIR/src/libraylib.a"

mkdir -p "$THIRD_PARTY"

# ---------------------------------------------------------------
# Step 1: fetch raylib source (if missing) and pin to RAYLIB_VERSION
# ---------------------------------------------------------------
if [ ! -d "$RAYLIB_DIR/.git" ]; then
    echo "build-raylib-native: cloning raylib $RAYLIB_VERSION into $RAYLIB_DIR"
    rm -rf "$RAYLIB_DIR"
    git clone --depth 1 --branch "$RAYLIB_VERSION" \
        https://github.com/raysan5/raylib.git "$RAYLIB_DIR"
else
    CURRENT_TAG="$(git -C "$RAYLIB_DIR" describe --tags --exact-match 2>/dev/null || echo '')"
    if [ "$CURRENT_TAG" != "$RAYLIB_VERSION" ]; then
        echo "build-raylib-native: raylib checkout at '$CURRENT_TAG', switching to '$RAYLIB_VERSION'"
        git -C "$RAYLIB_DIR" fetch --depth 1 origin "refs/tags/$RAYLIB_VERSION:refs/tags/$RAYLIB_VERSION"
        git -C "$RAYLIB_DIR" checkout -f "tags/$RAYLIB_VERSION"
        RAYLIB_FORCE=1
    fi
fi

# ---------------------------------------------------------------
# Step 2: apply patches (same set as web; see scripts/build-raylib-web.sh
# for rationale). Patch list lives in patches/*.patch.
# ---------------------------------------------------------------
PATCH_DIR="$REPO_ROOT/patches"
if [ -d "$PATCH_DIR" ]; then
    for p in "$PATCH_DIR"/*.patch; do
        [ -f "$p" ] || continue
        pname="$(basename "$p")"
        if git -C "$RAYLIB_DIR" apply --reverse --check "$p" >/dev/null 2>&1; then
            echo "build-raylib-native: patch $pname already applied, skipping"
        elif git -C "$RAYLIB_DIR" apply --check "$p" >/dev/null 2>&1; then
            echo "build-raylib-native: applying $pname"
            git -C "$RAYLIB_DIR" apply "$p"
            RAYLIB_FORCE=1
        else
            echo "build-raylib-native: ERROR patch $pname no longer applies cleanly against raylib $RAYLIB_VERSION" >&2
            echo "  Rebase $p and re-run. See patches/README.md." >&2
            exit 1
        fi
    done

    # Force rebuild when any patch is newer than the built archive so
    # patch edits take effect without RAYLIB_FORCE=1 (mirrors the web
    # script).
    if [ -f "$LIBRAYLIB" ] && find "$PATCH_DIR" -maxdepth 1 -name '*.patch' -newer "$LIBRAYLIB" -print -quit 2>/dev/null | grep -q .; then
        echo "build-raylib-native: patches newer than $LIBRAYLIB — forcing rebuild"
        RAYLIB_FORCE=1
    fi
fi

# ---------------------------------------------------------------
# Step 3: build libraylib.a for PLATFORM_DESKTOP (skip if up-to-date)
# ---------------------------------------------------------------
if [ -f "$LIBRAYLIB" ] && [ "$RAYLIB_FORCE" != "1" ]; then
    echo "build-raylib-native: $LIBRAYLIB already built (RAYLIB_FORCE=1 to rebuild)"
    exit 0
fi

echo "build-raylib-native: building raylib PLATFORM_DESKTOP"
cd "$RAYLIB_DIR/src"
make clean >/dev/null 2>&1 || true
make PLATFORM=PLATFORM_DESKTOP -B

if [ ! -f "$LIBRAYLIB" ]; then
    echo "build-raylib-native: ERROR build completed but $LIBRAYLIB missing" >&2
    exit 1
fi

echo "build-raylib-native: OK"
echo "  Library: $LIBRAYLIB"
echo "  Headers: $RAYLIB_DIR/src/{raylib,raymath,rlgl}.h"
