#!/bin/sh
# Pulls the **current branch** from origin (no local upstream needed), then rebuilds.
# Example on main: same as  git pull origin main && make ...
# Uses a normal merge pull (not --ff-only) so local commits on top of origin still work.
#
# WASM steps need emcc: set EMSDK to your emsdk dir, or put ./emsdk in the repo.
echo EMSDK=~/emsdk scripts/pullmake.sh
git remote set-url origin https://github.com/omiq/rgc-basic.git
set -e
# emsdk_env.sh needs cwd=emsdk/ in sh/dash; use wrapper (do not use a subshell or PATH is lost).
if [ -f ./scripts/emsdk-env.sh ]; then
  # shellcheck disable=SC1090
  . ./scripts/emsdk-env.sh || true
else
  _ems_prev=$(pwd)
  if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
    cd "$EMSDK" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
  elif [ -f ./emsdk/emsdk_env.sh ]; then
    cd ./emsdk || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
  elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    cd "$HOME/emsdk" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
  else
    echo "pullmake: warning: emsdk not found; WASM makes may fail (clone ./emsdk or set EMSDK)" >&2
  fi
  unset _ems_prev
fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$BRANCH"
make clean
make
# basic-gfx links the patched raylib from third_party/raylib-native
# (built on demand by scripts/build-raylib-native.sh). No system raylib
# needed. Requires a native toolchain (cc + make) plus the platform libs
# raylib itself depends on (X11/OpenGL on Linux, Xcode CLT on macOS,
# MinGW + make on Windows). See scripts/build-raylib-native.sh header.
make basic-gfx
make basic-wasm
make basic-wasm-modular
make basic-wasm-canvas
# raylib-emscripten build.
#
# scripts/build-raylib-web.sh is idempotent and handles three cases:
#   1. third_party/raylib-src missing  -> clones raylib at RAYLIB_VERSION
#   2. patches/*.patch newer than libraylib.a -> rebuilds the archive
#   3. already up to date              -> exits in a few milliseconds
#
# Calling it here (instead of gating on the archive existing) means fresh
# clones of rgc-basic bootstrap automatically AND patch edits in
# patches/*.patch propagate into libraylib.a on the next pullmake without
# the caller remembering to pass RAYLIB_FORCE=1. See patches/README.md
# and CHANGELOG.md "MOD load freeze fix (2026-04-20)".
if scripts/build-raylib-web.sh; then
  make basic-wasm-raylib
else
  echo "pullmake: skipping basic-wasm-raylib (scripts/build-raylib-web.sh failed — see output above)" >&2
fi
# Optional (needs Playwright): make wasm-test && make wasm-canvas-test && make wasm-tutorial-test
# Or canvas-only gate: sh scripts/verify-canvas-wasm.sh
cp -r web/*.* ../8bitworkshop/rgc-basic
cp -r examples/*.* ../8bitworkshop/presets/rgc-basic/
cd wordpress/rgc-basic-tutorial-block/
./copy-web-assets.sh --upload
cd ../..
