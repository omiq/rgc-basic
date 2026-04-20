#!/bin/sh
# Fetch + build raylib for Emscripten (PLATFORM_WEB).
#
# Output:
#   third_party/raylib-src/src/libraylib.a
#   third_party/raylib-src/src/*.h  (raylib.h, raymath.h, rlgl.h)
#
# These artefacts are gitignored. Re-run this script after bumping
# RAYLIB_VERSION below or after `rm -rf third_party/raylib-src/` for a clean
# rebuild. The Makefile target `basic-wasm-raylib` (added later) depends on
# libraylib.a existing at the path above.
#
# Requirements:
#   - emsdk activated in the current shell, OR a usable emsdk discovered
#     via EMSDK, ./emsdk, or ~/emsdk (same search order as pullmake.sh).
#   - make, git, standard POSIX shell.
#
# Typical usage:
#   EMSDK=~/emsdk scripts/build-raylib-web.sh
#
# Env vars:
#   RAYLIB_VERSION   git tag to check out (default: 5.5 — raylib 6.0 not yet released)
#   RAYLIB_GRAPHICS  GRAPHICS_API_OPENGL_ES2 (default) or GRAPHICS_API_OPENGL_ES3
#                    ES2 is the safe choice for older iOS / Android browsers.
#                    Switch to ES3 only if we start depending on GLSL 300 features.
#   RAYLIB_FORCE     set to 1 to force a clean rebuild even if libraylib.a exists.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RAYLIB_VERSION="${RAYLIB_VERSION:-5.5}"
RAYLIB_GRAPHICS="${RAYLIB_GRAPHICS:-GRAPHICS_API_OPENGL_ES2}"
RAYLIB_FORCE="${RAYLIB_FORCE:-0}"

THIRD_PARTY="$REPO_ROOT/third_party"
RAYLIB_DIR="$THIRD_PARTY/raylib-src"
LIBRAYLIB="$RAYLIB_DIR/src/libraylib.a"

mkdir -p "$THIRD_PARTY"

# ---------------------------------------------------------------
# Step 1: activate emsdk (mirrors scripts/pullmake.sh search order)
# ---------------------------------------------------------------
_ems_prev="$(pwd)"
if [ -f "$REPO_ROOT/scripts/emsdk-env.sh" ]; then
    # shellcheck disable=SC1090
    . "$REPO_ROOT/scripts/emsdk-env.sh" || true
elif [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
    cd "$EMSDK" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
elif [ -f "$REPO_ROOT/emsdk/emsdk_env.sh" ]; then
    cd "$REPO_ROOT/emsdk" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    cd "$HOME/emsdk" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
else
    echo "build-raylib-web: ERROR emsdk not found" >&2
    echo "  Expected one of: \$EMSDK/emsdk_env.sh, $REPO_ROOT/emsdk/emsdk_env.sh, ~/emsdk/emsdk_env.sh" >&2
    exit 1
fi
unset _ems_prev

if ! command -v emcc >/dev/null 2>&1; then
    echo "build-raylib-web: ERROR emcc not in PATH after sourcing emsdk_env.sh" >&2
    exit 1
fi

# ---------------------------------------------------------------
# Step 2: fetch raylib source (if missing) and pin to RAYLIB_VERSION
# ---------------------------------------------------------------
if [ ! -d "$RAYLIB_DIR/.git" ]; then
    echo "build-raylib-web: cloning raylib $RAYLIB_VERSION into $RAYLIB_DIR"
    rm -rf "$RAYLIB_DIR"
    git clone --depth 1 --branch "$RAYLIB_VERSION" \
        https://github.com/raysan5/raylib.git "$RAYLIB_DIR"
else
    CURRENT_TAG="$(git -C "$RAYLIB_DIR" describe --tags --exact-match 2>/dev/null || echo '')"
    if [ "$CURRENT_TAG" != "$RAYLIB_VERSION" ]; then
        echo "build-raylib-web: raylib checkout at '$CURRENT_TAG', switching to '$RAYLIB_VERSION'"
        git -C "$RAYLIB_DIR" fetch --depth 1 origin "refs/tags/$RAYLIB_VERSION:refs/tags/$RAYLIB_VERSION"
        git -C "$RAYLIB_DIR" checkout -f "tags/$RAYLIB_VERSION"
        RAYLIB_FORCE=1
    fi
fi

# ---------------------------------------------------------------
# Step 2b: apply RGC-BASIC patches from patches/*.patch
#
# Rationale: third_party/ is gitignored and clobbered by any clean
# rebuild, so upstream fixes we maintain ourselves must live in the
# RGC-BASIC repo and be re-applied on every build. Patches are
# idempotent — already-applied patches are detected via
# `git apply --reverse --check` and skipped without error.
#
# CURRENT PATCHES (keep this list in sync with patches/):
#   - jar_mod_max_samples.patch   — fixes LOADMUSIC browser freeze on
#                                   MOD files (see CHANGELOG.md
#                                   "MOD load freeze fix (2026-04-20)")
#
# If you bump RAYLIB_VERSION and a hunk no longer applies, the build
# fails here with a clear error. Rebase the patch against the new tag
# and re-run. Do NOT delete a patch just to make the build pass —
# re-check upstream first (the fix may have been merged).
# ---------------------------------------------------------------
PATCH_DIR="$REPO_ROOT/patches"
if [ -d "$PATCH_DIR" ]; then
    for p in "$PATCH_DIR"/*.patch; do
        [ -f "$p" ] || continue
        pname="$(basename "$p")"
        if git -C "$RAYLIB_DIR" apply --reverse --check "$p" >/dev/null 2>&1; then
            echo "build-raylib-web: patch $pname already applied, skipping"
        elif git -C "$RAYLIB_DIR" apply --check "$p" >/dev/null 2>&1; then
            echo "build-raylib-web: applying $pname"
            git -C "$RAYLIB_DIR" apply "$p"
            RAYLIB_FORCE=1
        else
            echo "build-raylib-web: ERROR patch $pname no longer applies cleanly against raylib $RAYLIB_VERSION" >&2
            echo "  Rebase $p and re-run. See patches/README.md." >&2
            exit 1
        fi
    done

    # If any patch file on disk is newer than the built archive, force a
    # rebuild even when every patch is already applied in-tree. Covers the
    # "edit a patch, re-run build" path: the Edit already landed in the
    # live tree via the previous build's apply step, so the reverse-check
    # above treats it as already-applied — but libraylib.a still reflects
    # the OLDER patch content and must be recompiled.
    if [ -f "$LIBRAYLIB" ] && find "$PATCH_DIR" -maxdepth 1 -name '*.patch' -newer "$LIBRAYLIB" -print -quit 2>/dev/null | grep -q .; then
        echo "build-raylib-web: patches newer than $LIBRAYLIB — forcing rebuild"
        RAYLIB_FORCE=1
    fi
fi

# ---------------------------------------------------------------
# Step 3: build libraylib.a for PLATFORM_WEB (skip if up-to-date)
# ---------------------------------------------------------------
if [ -f "$LIBRAYLIB" ] && [ "$RAYLIB_FORCE" != "1" ]; then
    echo "build-raylib-web: $LIBRAYLIB already built (RAYLIB_FORCE=1 to rebuild)"
    exit 0
fi

echo "build-raylib-web: building raylib PLATFORM_WEB ($RAYLIB_GRAPHICS)"
cd "$RAYLIB_DIR/src"
make clean >/dev/null 2>&1 || true
make PLATFORM=PLATFORM_WEB GRAPHICS="$RAYLIB_GRAPHICS" -B

if [ ! -f "$LIBRAYLIB" ]; then
    echo "build-raylib-web: ERROR build completed but $LIBRAYLIB missing" >&2
    exit 1
fi

echo "build-raylib-web: OK"
echo "  Library: $LIBRAYLIB"
echo "  Headers: $RAYLIB_DIR/src/{raylib,raymath,rlgl}.h"
