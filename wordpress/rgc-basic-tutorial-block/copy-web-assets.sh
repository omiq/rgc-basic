#!/usr/bin/env sh
# Copy RGC-BASIC web assets from a git checkout into this plugin.
# Usage: from plugin directory: ./copy-web-assets.sh [/path/to/rgc-basic/repo]

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:-$(cd "$ROOT/../.." 2>/dev/null && pwd)}"
if [ ! -f "$REPO/web/tutorial-embed.js" ]; then
  echo "error: cannot find $REPO/web/tutorial-embed.js" >&2
  echo "Usage: $0 /path/to/rgc-basic" >&2
  exit 1
fi

mkdir -p "$ROOT/assets/js" "$ROOT/assets/wasm"
cp -f "$REPO/web/tutorial-embed.js" "$ROOT/assets/js/"
cp -f "$REPO/web/vfs-helpers.js" "$ROOT/assets/js/"
if [ -f "$REPO/web/basic-modular.js" ] && [ -f "$REPO/web/basic-modular.wasm" ]; then
  cp -f "$REPO/web/basic-modular.js" "$REPO/web/basic-modular.wasm" "$ROOT/assets/wasm/"
  echo "Copied JS helpers + basic-modular.js/.wasm"
else
  echo "Copied JS helpers only. Build WASM in the repo: make basic-wasm-modular"
  echo "Then re-run this script or copy web/basic-modular.js and .wasm to assets/wasm/"
fi
