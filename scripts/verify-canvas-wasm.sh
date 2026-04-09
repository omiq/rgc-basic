#!/bin/sh
# Build canvas WASM and run the browser regression test (PEEK keys during SLEEP, TI, etc.).
# Requires: emcc (emsdk), pip install -r tests/requirements-wasm.txt, playwright install chromium
set -e
cd "$(dirname "$0")/.." || exit 1
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
  elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    cd "$HOME/emsdk" || exit 1
    # shellcheck disable=SC1091
    . ./emsdk_env.sh
    cd "$_ems_prev" || true
  fi
  unset _ems_prev
fi
make verify-canvas-wasm
echo "verify-canvas-wasm: OK"
