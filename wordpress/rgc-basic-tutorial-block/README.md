# RGC-BASIC Tutorial Embed (WordPress plugin)

Gutenberg block **RGC-BASIC embed** (`rgc-basic/tutorial-embed`) that loads `tutorial-embed.js`, `vfs-helpers.js`, and (from your site) `basic-modular.js` + `basic-modular.wasm`.

## Install

1. Copy this entire folder to `wp-content/plugins/rgc-basic-tutorial-block/`.
2. Activate **RGC-BASIC Tutorial Embed** under Plugins.
3. Add the block to a post or page.

## Ship WASM files

From an RGC-BASIC checkout:

```bash
cd wordpress/rgc-basic-tutorial-block
./copy-web-assets.sh /path/to/rgc-basic
```

Or manually copy into `assets/wasm/`:

- `web/basic-modular.js`
- `web/basic-modular.wasm`

And into `assets/js/` (or re-run the script):

- `web/tutorial-embed.js`
- `web/vfs-helpers.js`

## Custom WASM URL

**Settings → RGC-BASIC Tutorial** — set a base URL ending in `/` where both modular files are hosted (e.g. your CDN).

Developers can also use:

```php
add_filter( 'rgc_basic_tutorial_wasm_base_url', function () {
    return 'https://cdn.example.com/rgc-basic/';
});
```

## Block options

Stored as block attributes: `program`, `showEditor`, `showPauseStop`, `showVfsTools`, `editorMinHeight`, `outputMinHeight`. The PHP render callback passes them to `RgcBasicTutorialEmbed.mount` (with `baseUrl`).

Filter for advanced cases:

```php
add_filter( 'rgc_basic_tutorial_embed_options', function ( $opts, $attributes, $block ) {
    // e.g. $opts['flags'] = '-petscii -palette ansi -charset upper';
    return $opts;
}, 10, 3 );
```

## Files

| Path | Role |
|------|------|
| `rgc-basic-tutorial-block.php` | Plugin bootstrap, enqueue, render callback, settings |
| `block.json` | Block metadata + attributes |
| `build/block-editor.js` | Block editor UI |
| `build/frontend-init.js` | Finds configs and calls `RgcBasicTutorialEmbed.mount` |
| `build/block-frontend.css` | Light wrapper spacing |
| `assets/js/` | Copied from repo `web/` |
| `assets/wasm/` | Copied modular build output |

See also [tutorial-embedding.md](../../docs/tutorial-embedding.md) in the main repository.
