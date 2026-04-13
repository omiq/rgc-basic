=== RGC-BASIC Tutorial Embed ===
Contributors: rgc-basic
Tags: block, gutenberg, basic, code, tutorial, wasm
Requires at least: 6.0
Tested up to: 6.7
Requires PHP: 7.4
Stable tag: 1.2.7
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Embed one or more RGC-BASIC interpreters in posts and pages (WebAssembly).

== Description ==

Adds a **RGC-BASIC embed** block. Each block runs the modular WASM build in the visitor's browser (same stack as `web/tutorial-embed.js` in the RGC-BASIC repo).

* Multiple blocks per page — each instance is isolated.
* Options: initial program text, show/hide editor, pause/stop, VFS tools, min heights.
* **Settings → RGC-BASIC Tutorial** — optional override URL for `basic-modular.js` / `basic-modular.wasm` (must be HTTPS on public sites).

== Installation ==

1. Copy the folder `rgc-basic-tutorial-block` to `wp-content/plugins/`.
2. Ensure `assets/wasm/` contains `basic-modular.js` and `basic-modular.wasm` (from `make basic-wasm-modular` in the RGC-BASIC repo), or use **copy-web-assets.sh** from the plugin directory pointing at your git checkout.
3. Activate the plugin in **Plugins**.
4. Add the **RGC-BASIC embed** block in the editor.

== Frequently Asked Questions ==

= Why does nothing run? =

WASM must be served over **HTTPS** (or localhost). If files are missing, configure a CDN URL under **Settings → RGC-BASIC Tutorial**.

= Can I style the embed? =

Yes. The helper adds classes such as `rgc-tutorial-embed` (see `docs/tutorial-embedding.md` in the RGC-BASIC repo).

== Changelog ==

= 1.2.7 =
* Explicit apiVersion 3 in block editor JS for WordPress 6.9 iframe inserter (GFX block was registered but hidden from search).

= 1.2.6 =
* Same as 1.2.2; plugin PHP entry file may be **`rgc-basic-blocks.php`**.

= 1.2.2 =
* GFX editor script renamed to **`build/gfx-block-editor.js`** (distinct name so FTP does not overwrite it with `block-editor.js`). Purge CDN if Cloudflare cached the wrong file.

= 1.2.1 =
* Block editor always enqueues the GFX editor script (not only via block.json) so the GFX block registers even with stale JSON or PHP opcode cache.

= 1.2.0 =
* GFX block uses a separate editor script file (see 1.2.2 for final name **`gfx-block-editor.js`**) so the canvas block appears reliably after FTP upload.

= 1.1.0 =
* Second block: **RGC-BASIC GFX embed** (canvas WASM). See plugin README: upload `build/block-editor.js` + `frontend-gfx-init.js` together or the new block will not appear.

= 1.0.0 =
* Initial release: dynamic block, asset enqueue, optional WASM base URL setting.
