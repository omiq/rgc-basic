#!/bin/sh
# Server / CI-style: pull + WASM artifacts only (no native basic, no Raylib basic-gfx).
# Requires: emsdk on PATH (see below), emcc.
git remote set-url origin https://github.com/omiq/rgc-basic.git
set -e
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$BRANCH"

if [ -f ./scripts/emsdk-env.sh ]; then
  # shellcheck disable=SC1090
  . ./scripts/emsdk-env.sh
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
    echo "pullmake-wasm: set EMSDK or clone ./emsdk, then:" >&2
    echo "  cd emsdk && ./emsdk install latest && ./emsdk activate latest" >&2
    exit 1
  fi
  unset _ems_prev
fi

make clean
make basic-wasm
make basic-wasm-modular
make basic-wasm-canvas
# Optional: make wasm-test && make wasm-canvas-test && make wasm-tutorial-test
