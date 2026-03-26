#!/bin/sh
# Source this file before WASM builds if emcc is not on PATH:
#   . scripts/emsdk-env.sh
# Or from repo root: . ./emsdk/emsdk_env.sh
#
# emsdk lives at ./emsdk (gitignored). Install once:
#   git clone https://github.com/emscripten-core/emsdk.git emsdk
#   cd emsdk && ./emsdk install latest && ./emsdk activate latest

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ -f "$REPO_ROOT/emsdk/emsdk_env.sh" ]; then
  # shellcheck disable=SC1090
  . "$REPO_ROOT/emsdk/emsdk_env.sh"
elif [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  # shellcheck disable=SC1090
  . "$EMSDK/emsdk_env.sh"
else
  echo "scripts/emsdk-env.sh: no emsdk found. Clone: git clone https://github.com/emscripten-core/emsdk.git $REPO_ROOT/emsdk" >&2
  return 1 2>/dev/null || exit 1
fi
