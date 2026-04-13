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
# Canvas GFX WordPress shell (not under web/ — ships in assets/js/ in git)
GFX_HERE="$ROOT/assets/js/gfx-embed-mount.js"
GFX_IN_REPO="$REPO/wordpress/rgc-basic-tutorial-block/assets/js/gfx-embed-mount.js"
if [ -f "$GFX_HERE" ]; then
	echo "gfx-embed-mount.js already in assets/js/ (GFX embed block)"
elif [ -f "$GFX_IN_REPO" ]; then
	cp -f "$GFX_IN_REPO" "$ROOT/assets/js/"
	echo "Copied gfx-embed-mount.js from \$REPO wordpress path (GFX embed block)"
else
	echo "warning: gfx-embed-mount.js missing — run 'git pull' in rgc-basic, or copy assets/js/gfx-embed-mount.js from the plugin on GitHub" >&2
fi
if [ -f "$REPO/web/basic-modular.js" ] && [ -f "$REPO/web/basic-modular.wasm" ]; then
  cp -f "$REPO/web/basic-modular.js" "$REPO/web/basic-modular.wasm" "$ROOT/assets/wasm/"
  echo "Copied JS helpers + basic-modular.js/.wasm"
else
  echo "Copied JS helpers only. Build WASM in the repo: make basic-wasm-modular"
  echo "Then re-run this script or copy web/basic-modular.js and .wasm to assets/wasm/"
fi

if [ -f "$REPO/web/basic-canvas.js" ] && [ -f "$REPO/web/basic-canvas.wasm" ]; then
  cp -f "$REPO/web/basic-canvas.js" "$REPO/web/basic-canvas.wasm" "$ROOT/assets/wasm/"
  echo "Copied basic-canvas.js/.wasm (GFX embed block)"
else
  echo "No basic-canvas.js/.wasm found. For the GFX block run: make basic-wasm-canvas"
fi
