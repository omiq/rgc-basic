#!/bin/sh
# Pulls the **current branch** from origin (no local upstream needed), then rebuilds.
# Example on main: same as  git pull origin main && make ...
# Uses a normal merge pull (not --ff-only) so local commits on top of origin still work.
#
# WASM steps need emcc: set EMSDK to your emsdk dir, or put ./emsdk in the repo.
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
