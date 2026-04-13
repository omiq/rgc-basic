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

# Gutenberg build/*.js — not produced by make; ship in git under wordpress/rgc-basic-tutorial-block/build/
# If this script lives inside $REPO/wordpress/.../ then BUILD_SRC is the same dir as $ROOT/build — skip cp (avoids "identical (not copied)" / error).
BUILD_SRC="$REPO/wordpress/rgc-basic-tutorial-block/build"
if [ -d "$BUILD_SRC" ]; then
  BUILD_SAME=
  if [ -d "$ROOT/build" ]; then
    if [ "$(cd "$ROOT/build" && pwd)" = "$(cd "$BUILD_SRC" && pwd)" ]; then
      BUILD_SAME=1
    fi
  fi
  if [ -n "$BUILD_SAME" ]; then
    echo "build/ already this checkout (run from plugin inside repo — nothing to sync)"
  else
    mkdir -p "$ROOT/build"
    for f in block-editor.js gfx-block-editor.js frontend-init.js frontend-gfx-init.js block-frontend.css; do
      if [ -f "$BUILD_SRC/$f" ]; then
        cp -f "$BUILD_SRC/$f" "$ROOT/build/"
      fi
    done
    echo "Synced build/ from repo (block-editor.js, gfx-block-editor.js, frontend-*.js, CSS)"
  fi
fi
