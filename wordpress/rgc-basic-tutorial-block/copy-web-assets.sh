#!/usr/bin/env sh
# Copy RGC-BASIC web assets from a git checkout into this plugin, and
# optionally assemble a clean FTP-ready staging folder.
#
# Usage (from plugin directory):
#   ./copy-web-assets.sh [/path/to/rgc-basic/repo] [--deploy [DIR]] [--upload]
#
# With --deploy (optional DIR, default: ./deploy/rgc-basic-tutorial-block) the
# script mirrors the plugin into DIR containing ONLY the files the server
# needs. Upload DIR to wp-content/plugins/rgc-basic-tutorial-block/ via FTP.
#
# With --upload (implies --deploy) the deploy folder contents are pushed via
# scp to the Siteground host. Override via env vars:
#   RGC_SSH_USER  (default: u1562-xtlviwl6bhzb)
#   RGC_SSH_HOST  (default: gcam1228.siteground.biz)
#   RGC_SSH_PORT  (default: 18765)   # Siteground non-standard SSH port
#   RGC_SSH_PATH  (default: /home/u1562-xtlviwl6bhzb/www/retrogamecoders.com/public_html/wp-content/plugins/rgc-basic-tutorial-block)
#
# Files kept in deploy:
#   rgc-basic-blocks.php
#   block.json                      (root — terminal block metadata)
#   blocks/gfx/block.json           (GFX block metadata — required for server-side register_block_type)
#   build/*.js  build/*.css         (editor + frontend bundles)
#   assets/js/*.js                  (tutorial-embed, gfx-embed-mount, vfs-helpers)
#   assets/wasm/basic-modular.*     (terminal WASM)
#   assets/wasm/basic-canvas.*      (GFX WASM)
#   readme.txt  README.md  LICENSE (if present)
#
# Any junk like .DS_Store / *.map / node_modules is skipped.

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Parse positional REPO and optional --deploy [DIR] / --upload.
REPO=""
DEPLOY=""
DEPLOY_DIR=""
UPLOAD=""
while [ $# -gt 0 ]; do
	case "$1" in
		--deploy)
			DEPLOY=1
			# If next arg exists and is not another flag, treat as DIR.
			if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then
				DEPLOY_DIR="$2"
				shift
			fi
			;;
		--deploy=*)
			DEPLOY=1
			DEPLOY_DIR="${1#--deploy=}"
			;;
		--upload)
			UPLOAD=1
			DEPLOY=1
			;;
		-h|--help)
			sed -n '2,19p' "$0"
			exit 0
			;;
		*)
			if [ -z "$REPO" ]; then
				REPO="$1"
			else
				echo "error: unexpected arg: $1" >&2
				exit 2
			fi
			;;
	esac
	shift
done

if [ -z "$REPO" ]; then
	REPO="$(cd "$ROOT/../.." 2>/dev/null && pwd)"
fi

if [ ! -f "$REPO/web/tutorial-embed.js" ]; then
	echo "error: cannot find $REPO/web/tutorial-embed.js" >&2
	echo "Usage: $0 /path/to/rgc-basic [--deploy [DIR]]" >&2
	exit 1
fi

mkdir -p "$ROOT/assets/js" "$ROOT/assets/wasm" "$ROOT/blocks/gfx"

# ----- assets/js (from web/) -----
cp -f "$REPO/web/tutorial-embed.js" "$ROOT/assets/js/"
cp -f "$REPO/web/vfs-helpers.js"    "$ROOT/assets/js/"

# Canvas GFX WordPress shell (not under web/ — ships in assets/js/ in git).
GFX_HERE="$ROOT/assets/js/gfx-embed-mount.js"
GFX_IN_REPO="$REPO/wordpress/rgc-basic-tutorial-block/assets/js/gfx-embed-mount.js"
if [ -f "$GFX_IN_REPO" ] && [ "$GFX_IN_REPO" != "$GFX_HERE" ]; then
	cp -f "$GFX_IN_REPO" "$ROOT/assets/js/"
	echo "Copied gfx-embed-mount.js from \$REPO (GFX embed block)"
elif [ -f "$GFX_HERE" ]; then
	echo "gfx-embed-mount.js already in assets/js/ (GFX embed block)"
else
	echo "warning: gfx-embed-mount.js missing — run 'git pull' in rgc-basic, or copy assets/js/gfx-embed-mount.js from the plugin on GitHub" >&2
fi

# Shared syntax highlighter (used by both tutorial + gfx embeds).
HL_HERE="$ROOT/assets/js/basic-highlight.js"
HL_IN_REPO="$REPO/wordpress/rgc-basic-tutorial-block/assets/js/basic-highlight.js"
if [ -f "$HL_IN_REPO" ] && [ "$HL_IN_REPO" != "$HL_HERE" ]; then
	cp -f "$HL_IN_REPO" "$ROOT/assets/js/"
	echo "Copied basic-highlight.js from \$REPO (shared highlighter)"
elif [ -f "$HL_HERE" ]; then
	echo "basic-highlight.js already in assets/js/ (shared highlighter)"
else
	echo "warning: basic-highlight.js missing — run 'git pull' in rgc-basic, or copy assets/js/basic-highlight.js from the plugin on GitHub" >&2
fi

# ----- assets/wasm (from web/) -----
if [ -f "$REPO/web/basic-modular.js" ] && [ -f "$REPO/web/basic-modular.wasm" ]; then
	cp -f "$REPO/web/basic-modular.js"   "$ROOT/assets/wasm/"
	cp -f "$REPO/web/basic-modular.wasm" "$ROOT/assets/wasm/"
	echo "Copied basic-modular.js/.wasm"
else
	echo "No basic-modular.js/.wasm. In the repo run: make basic-wasm-modular" >&2
fi

if [ -f "$REPO/web/basic-canvas.js" ] && [ -f "$REPO/web/basic-canvas.wasm" ]; then
	cp -f "$REPO/web/basic-canvas.js"   "$ROOT/assets/wasm/"
	cp -f "$REPO/web/basic-canvas.wasm" "$ROOT/assets/wasm/"
	echo "Copied basic-canvas.js/.wasm (GFX embed block)"
else
	echo "No basic-canvas.js/.wasm. For the GFX block run: make basic-wasm-canvas" >&2
fi

# ----- blocks/*/block.json (server-side block metadata) -----
# WP's register_block_type() only accepts files named exactly block.json under
# the directory passed to it. If these aren't uploaded, the GFX block will not
# appear in the inserter (REST returns 404 rest_block_type_invalid).
BLOCKS_SRC="$REPO/wordpress/rgc-basic-tutorial-block/blocks"
if [ -d "$BLOCKS_SRC" ] && [ "$(cd "$BLOCKS_SRC" && pwd)" != "$(cd "$ROOT/blocks" 2>/dev/null && pwd)" ]; then
	# shellcheck disable=SC2044
	for bj in $(find "$BLOCKS_SRC" -mindepth 2 -maxdepth 2 -name block.json 2>/dev/null); do
		rel="${bj#$BLOCKS_SRC/}"
		dst="$ROOT/blocks/$rel"
		mkdir -p "$(dirname "$dst")"
		cp -f "$bj" "$dst"
		echo "Synced blocks/$rel"
	done
fi
if [ ! -f "$ROOT/blocks/gfx/block.json" ]; then
	echo "warning: blocks/gfx/block.json is missing — GFX block will not register server-side" >&2
fi

# ----- build/ (Gutenberg bundles — not from make, shipped in git) -----
BUILD_SRC="$REPO/wordpress/rgc-basic-tutorial-block/build"
if [ -d "$BUILD_SRC" ]; then
	BUILD_SAME=
	if [ -d "$ROOT/build" ] && [ "$(cd "$ROOT/build" && pwd)" = "$(cd "$BUILD_SRC" && pwd)" ]; then
		BUILD_SAME=1
	fi
	if [ -n "$BUILD_SAME" ]; then
		echo "build/ already this checkout (nothing to sync)"
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

# ----- Optional: assemble a clean FTP-ready staging folder. -----
if [ -n "$DEPLOY" ]; then
	if [ -z "$DEPLOY_DIR" ]; then
		DEPLOY_DIR="$ROOT/deploy/rgc-basic-tutorial-block"
	fi
	rm -rf "$DEPLOY_DIR"
	mkdir -p "$DEPLOY_DIR" \
		"$DEPLOY_DIR/build" \
		"$DEPLOY_DIR/blocks/gfx" \
		"$DEPLOY_DIR/assets/js" \
		"$DEPLOY_DIR/assets/wasm"

	# Root PHP + metadata + readmes.
	cp -f "$ROOT/rgc-basic-blocks.php"  "$DEPLOY_DIR/"
	cp -f "$ROOT/block.json"            "$DEPLOY_DIR/"
	[ -f "$ROOT/readme.txt" ] && cp -f "$ROOT/readme.txt" "$DEPLOY_DIR/"
	[ -f "$ROOT/README.md"  ] && cp -f "$ROOT/README.md"  "$DEPLOY_DIR/"
	[ -f "$ROOT/LICENSE"    ] && cp -f "$ROOT/LICENSE"    "$DEPLOY_DIR/"

	# Per-block metadata.
	if [ -f "$ROOT/blocks/gfx/block.json" ]; then
		cp -f "$ROOT/blocks/gfx/block.json" "$DEPLOY_DIR/blocks/gfx/"
	else
		echo "error: blocks/gfx/block.json missing in source — refusing to build incomplete deploy" >&2
		exit 3
	fi

	# Gutenberg bundles.
	for f in block-editor.js gfx-block-editor.js frontend-init.js frontend-gfx-init.js block-frontend.css; do
		if [ -f "$ROOT/build/$f" ]; then
			cp -f "$ROOT/build/$f" "$DEPLOY_DIR/build/"
		else
			echo "warning: build/$f missing" >&2
		fi
	done

	# Frontend JS shells.
	for f in tutorial-embed.js vfs-helpers.js gfx-embed-mount.js basic-highlight.js; do
		if [ -f "$ROOT/assets/js/$f" ]; then
			cp -f "$ROOT/assets/js/$f" "$DEPLOY_DIR/assets/js/"
		else
			echo "warning: assets/js/$f missing" >&2
		fi
	done

	# WASM payloads (both interpreters, if built).
	for f in basic-modular.js basic-modular.wasm basic-canvas.js basic-canvas.wasm; do
		if [ -f "$ROOT/assets/wasm/$f" ]; then
			cp -f "$ROOT/assets/wasm/$f" "$DEPLOY_DIR/assets/wasm/"
		else
			echo "note: assets/wasm/$f not present (skipped)" >&2
		fi
	done

	# Strip macOS + editor junk.
	find "$DEPLOY_DIR" \( -name .DS_Store -o -name '*.map' -o -name '*.bak' -o -name '*~' \) -delete 2>/dev/null || true

	echo ""
	echo "Deploy folder ready: $DEPLOY_DIR"
	echo "Upload the CONTENTS of that folder to:"
	echo "  wp-content/plugins/rgc-basic-tutorial-block/"
	echo ""
	echo "File tree:"
	( cd "$DEPLOY_DIR" && find . -type f | sort | sed 's|^\./|  |' )
fi

# ---------------------------------------------------------------------------
# Optional: scp the deploy folder contents up to the Siteground host.
# ---------------------------------------------------------------------------
if [ -n "$UPLOAD" ]; then
	SSH_USER="${RGC_SSH_USER:-u1562-xtlviwl6bhzb}"
	SSH_HOST="${RGC_SSH_HOST:-gcam1228.siteground.biz}"
	SSH_PORT="${RGC_SSH_PORT:-18765}"
	SSH_PATH="${RGC_SSH_PATH:-/home/u1562-xtlviwl6bhzb/www/retrogamecoders.com/public_html/wp-content/plugins/rgc-basic-tutorial-block}"

	if [ ! -d "$DEPLOY_DIR" ]; then
		echo "error: deploy dir $DEPLOY_DIR missing — cannot upload" >&2
		exit 4
	fi

	echo ""
	echo "Uploading $DEPLOY_DIR/ -> $SSH_USER@$SSH_HOST:$SSH_PATH (port $SSH_PORT)"

	# Default to scp — Siteground's shared-hosting rsync hits memory limits
	# ("error allocating core memory buffers"). Set RGC_USE_RSYNC=1 to override.
	if [ -n "${RGC_USE_RSYNC:-}" ] && command -v rsync >/dev/null 2>&1; then
		rsync -az \
			--exclude '.DS_Store' --exclude '*.map' --exclude '*.bak' --exclude '*~' \
			-e "ssh -p $SSH_PORT" \
			"$DEPLOY_DIR"/ \
			"$SSH_USER@$SSH_HOST:$SSH_PATH"/
	else
		# scp -O uses the legacy scp protocol (avoids SFTP memory overhead on
		# shared hosting). It rejects the "/." contents-copy trick, so cd into
		# the deploy dir and let the shell glob its contents.
		(
			cd "$DEPLOY_DIR" && \
			scp -P "$SSH_PORT" -O -r -- * \
				"$SSH_USER@$SSH_HOST:$SSH_PATH"/
		)
	fi

	echo "Upload complete."
fi
