#!/bin/sh
# Server / CI-style: pull + WASM artifacts only (no native basic, no Raylib basic-gfx).
# Requires: emsdk on PATH (see below), emcc.
set -e
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$BRANCH"

EMS_ENV=""
if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  EMS_ENV="$EMSDK/emsdk_env.sh"
elif [ -f ./emsdk/emsdk_env.sh ]; then
  EMS_ENV="./emsdk/emsdk_env.sh"
elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
  EMS_ENV="$HOME/emsdk/emsdk_env.sh"
fi
if [ -z "$EMS_ENV" ]; then
  echo "pullmake-wasm: set EMSDK to your emsdk directory, or clone:" >&2
  echo "  git clone https://github.com/emscripten-core/emsdk.git && cd emsdk && ./emsdk install latest && ./emsdk activate latest" >&2
  exit 1
fi
# shellcheck disable=SC1090
. "$EMS_ENV"

make clean
make basic-wasm
make basic-wasm-modular
make basic-wasm-canvas
# Optional: make wasm-test && make wasm-canvas-test && make wasm-tutorial-test
