# RGC-BASIC Tutorial Embed (WordPress plugin)

Two Gutenberg blocks:

- **RGC-BASIC embed** (`rgc-basic/tutorial-embed`) — terminal WASM: `tutorial-embed.js`, `vfs-helpers.js`, and `basic-modular.js` + `basic-modular.wasm`.
- **RGC-BASIC GFX embed** (`rgc-basic/gfx-embed`) — canvas / sprites: `gfx-embed-mount.js`, `vfs-helpers.js`, and `basic-canvas.js` + `basic-canvas.wasm` (same **WASM base URL** as the terminal build).

## Install

1. Copy this entire folder to `wp-content/plugins/rgc-basic-tutorial-block/`.
2. Activate **RGC-BASIC Tutorial Embed** under Plugins.
3. Add the block to a post or page.

### If you only see “RGC-BASIC embed” (terminal), not “RGC-BASIC GFX embed”

The GFX block uses a **separate** editor script so a stale `block-editor.js` cannot hide it. Upload **all** of these from the repo (same version / same batch):

- `build/block-editor.js` — terminal block only
- **`build/block-editor-gfx.js`** — GFX block (`rgc-basic/gfx-embed`); **required** — without it the second block will not appear in the inserter
- `build/frontend-gfx-init.js`
- `block-gfx.json` (must reference `editorScript`: `rgc-basic-tutorial-block-editor-gfx`)
- `rgc-basic-tutorial-block.php`
- `assets/js/gfx-embed-mount.js`

Then **Plugins → deactivate** RGC-BASIC Tutorial Embed → **Activate** again (or use a cache plugin’s “purge all caches”). Hard-refresh the block editor (**Ctrl+Shift+R** / **Cmd+Shift+R**). Search for **“gfx”** or **“canvas”** as well as **“rgc”**.

If DevTools **Network** shows **404** on **`gfx-embed-mount.js`**, that file must exist at **`wp-content/plugins/rgc-basic-tutorial-block/assets/js/gfx-embed-mount.js`**. Re-run **`copy-web-assets.sh`** from a full repo checkout (the script copies it), or copy that file from git into **`assets/js/`**.

## Ship WASM files

From an RGC-BASIC checkout:

```bash
cd wordpress/rgc-basic-tutorial-block
./copy-web-assets.sh /path/to/rgc-basic
```

Or manually copy into `assets/wasm/`:

- `web/basic-modular.js`
- `web/basic-modular.wasm`
- `web/basic-canvas.js` (GFX block)
- `web/basic-canvas.wasm` (GFX block; run `make basic-wasm-canvas` in the repo)

And into `assets/js/` (or re-run the script):

- `web/tutorial-embed.js`
- `web/vfs-helpers.js`

The file **`assets/js/gfx-embed-mount.js`** is part of the plugin in git (it is **not** produced by `make` or copied from `web/`). Run **`git pull`** in the RGC-BASIC repo so that file exists under **`wordpress/rgc-basic-tutorial-block/assets/js/`**. **`copy-web-assets.sh`** verifies it is present (or copies it from **`$REPO/wordpress/rgc-basic-tutorial-block/...`** when you pass the repo path). If that file is missing on the server, the block editor returns **404** for `gfx-embed-mount.js` — upload it into **`assets/js/`**.

## Custom WASM URL

**Settings → RGC-BASIC Tutorial** — set a base URL ending in `/` where both modular files are hosted (e.g. your CDN).

Developers can also use:

```php
add_filter( 'rgc_basic_tutorial_wasm_base_url', function () {
    return 'https://cdn.example.com/rgc-basic/';
});
```

## Block options

**Terminal embed** — attributes: `program`, `showEditor`, `showPauseStop`, `showVfsTools`, `editorMinHeight`, `outputMinHeight`. The PHP render callback passes them to `RgcBasicTutorialEmbed.mount` (with `baseUrl`).

**GFX embed** — attributes: `program`, `showEditor`, `showControls` (Run / Pause / Stop / Zoom), `showFullscreen`, `showVfsTools`, optional `posterImageUrl` (centered **Run** defers WASM load until click), and `interpreterFlags` (passed to `basic_apply_arg_string`). The render callback outputs JSON for `RgcBasicGfxEmbed.mount` (with `wasmBaseUrl`).

Filter for advanced cases:

```php
add_filter( 'rgc_basic_tutorial_embed_options', function ( $opts, $attributes, $block ) {
    // e.g. $opts['flags'] = '-petscii -palette ansi -charset upper';
    return $opts;
}, 10, 3 );

add_filter( 'rgc_basic_gfx_embed_options', function ( $opts, $attributes, $block ) {
    return $opts;
}, 10, 3 );
```

## Files

| Path | Role |
|------|------|
| `rgc-basic-tutorial-block.php` | Plugin bootstrap, enqueue, render callback, settings |
| `block.json` | Terminal block metadata + attributes |
| `block-gfx.json` | GFX block metadata + attributes |
| `build/block-editor.js` | Terminal block editor UI |
| `build/block-editor-gfx.js` | GFX block editor UI |
| `build/frontend-init.js` | Finds configs and calls `RgcBasicTutorialEmbed.mount` |
| `build/frontend-gfx-init.js` | Finds configs and calls `RgcBasicGfxEmbed.mount` |
| `assets/js/gfx-embed-mount.js` | Canvas WASM shell (from `canvas.html` logic) |
| `build/block-frontend.css` | Light wrapper spacing |
| `assets/js/` | Copied from repo `web/` |
| `assets/wasm/` | Copied modular build output |

See also [tutorial-embedding.md](../../docs/tutorial-embedding.md) in the main repository.

**Canvas / sprites / `SCREEN 1`:** Use the **RGC-BASIC GFX embed** block, or see **[`docs/wordpress-canvas-embed.md`](../../docs/wordpress-canvas-embed.md)** for iframe and custom HTML options.
