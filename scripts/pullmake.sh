#!/bin/sh
# Pulls the **current branch** from origin (no local upstream needed), then rebuilds.
# Example on main: same as  git pull origin main && make ...
# Uses a normal merge pull (not --ff-only) so local commits on top of origin still work.
#
# WASM steps need emcc: set EMSDK to your emsdk dir, or put ./emsdk in the repo.
set -e
EMS_ENV=""
if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  EMS_ENV="$EMSDK/emsdk_env.sh"
elif [ -f ./emsdk/emsdk_env.sh ]; then
  EMS_ENV="./emsdk/emsdk_env.sh"
elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
  EMS_ENV="$HOME/emsdk/emsdk_env.sh"
fi
if [ -n "$EMS_ENV" ]; then
  # shellcheck disable=SC1090
  . "$EMS_ENV"
else
  echo "pullmake: warning: emsdk_env.sh not found; WASM makes may fail (set EMSDK or clone ./emsdk)" >&2
fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$BRANCH"
make clean
make
# basic-gfx needs Raylib (pkg-config raylib). Skip if headers are not installed.
if pkg-config --exists raylib 2>/dev/null; then
  make basic-gfx
else
  echo "pullmake: skipping basic-gfx (raylib not found — e.g. apt install libraylib-dev)" >&2
fi
make basic-wasm
make basic-wasm-modular
make basic-wasm-canvas
# Optional: make wasm-test && make wasm-canvas-test && make wasm-tutorial-test  (needs Playwright)
