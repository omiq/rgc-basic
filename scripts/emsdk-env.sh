#!/bin/sh
# Put emcc on PATH for WASM builds. Safe for sh/dash (Cursor may use sh for integrated terminal).
#
# Usage (from anywhere inside the git repo):
#   . scripts/emsdk-env.sh
#
# One-time install:
#   git clone https://github.com/emscripten-core/emsdk.git emsdk
#   cd emsdk && ./emsdk install latest && ./emsdk activate latest
#
# emsdk's emsdk_env.sh uses BASH_SOURCE; in plain sh that is unset unless cwd is emsdk/,
# so we always cd there before sourcing, then return to the previous directory.

EMS_PREV=$(pwd)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  echo "emsdk-env.sh: not inside a git repo; cd to rgc-basic and try again, or:" >&2
  echo "  EMSDK=/path/to/emsdk && . \"\$EMSDK/emsdk_env.sh\"  (from inside \$EMSDK)" >&2
  return 1 2>/dev/null || exit 1
fi

EMS_DIR="$REPO_ROOT/emsdk"
if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  EMS_DIR="$EMSDK"
fi

if [ ! -f "$EMS_DIR/emsdk.py" ]; then
  echo "emsdk-env.sh: missing $EMS_DIR (clone emsdk there or set EMSDK=...)" >&2
  return 1 2>/dev/null || exit 1
fi

cd "$EMS_DIR" || return 1 2>/dev/null || exit 1
# shellcheck disable=SC1091
. ./emsdk_env.sh
cd "$EMS_PREV" || true
