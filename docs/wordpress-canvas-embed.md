# Embedding canvas WASM (sprites, `SCREEN 1`) in WordPress

The official plugin **`wordpress/rgc-basic-tutorial-block`** embeds the **terminal** build (`basic-modular.js` / `basic-modular.wasm` via **`tutorial-embed.js`**). That is enough for **`PRINT`**, **`INPUT`**, PETSCII in the output panel, etc. It does **not** load **`basic-canvas.js`** or a **`&lt;canvas&gt;`**, so programs that need **`LOADSPRITE`**, **`SCREEN 1`**, **`LINE`**, **`HTTPFETCH`** into MEMFS for PNGs, etc. must use one of the approaches below.

## Option 1 — Iframe a hosted `canvas.html` (simplest)

1. From an RGC-BASIC checkout, run **`make basic-wasm-canvas`**.
2. Upload **`web/basic-canvas.js`**, **`web/basic-canvas.wasm`**, and a copy of **`web/canvas.html`** (or a minimal variant) to your WordPress site or CDN **on the same origin** you trust for WASM (see **`docs/ide-retrogamecoders-canvas-integration.md`** — pair **`.js` and `.wasm`** with the same cache-bust query).
3. Adjust **`canvas.html`** (or your shell) so the **program textarea** is pre-filled or empty and you paste your demo, **or** pass the program from query/hash if you add a few lines of JS.
4. In the WordPress post, add a **Custom HTML** block:

```html
<iframe
  title="RGC-BASIC canvas demo"
  src="https://YOURSITE.com/path/to/canvas.html?cb=2026-04-14"
  width="100%"
  height="720"
  style="max-width:900px;border:1px solid #ccc;border-radius:8px"
  loading="lazy"
></iframe>
```

5. **Height:** The demo needs vertical space (PETSCII + controls + optional log). Tune **`height`** so Run/Pause/Stop and the canvas are visible without double scrollbars.

**CORS:** Your **`HTTPFETCH`** URLs must allow **`fetch`** from the **iframe’s origin** (usually your site). Same-origin media URLs work; other domains need **`Access-Control-Allow-Origin`**.

## Option 2 — Custom HTML + inline shell (no iframe)

Follow **`docs/ide-retrogamecoders-canvas-integration.md`**: define **`Module`**, **`locateFile`** for **`basic-canvas.wasm`**, load **`basic-canvas.js`**, add **`<canvas>`**, **Run / Pause / Stop**, and the **`requestAnimationFrame`** loop that reads **`wasm_gfx_rgba_ptr`** / **`wasm_gfx_rgba_version_read`** (copy the pattern from **`web/canvas.html`**). Paste that HTML into a **Custom HTML** block (only if your theme allows unfiltered HTML for admins).

This avoids an iframe but duplicates maintenance with upstream **`canvas.html`**.

## Option 3 — Keep terminal embed + link out

Use the **RGC-BASIC Tutorial** block for a **text-only** teaser, and link to a full-screen **`canvas.html`** on your domain for the Boing demo.

## Program path note

Your demo uses **`LOADSPRITE …, "boing_sheet.png"`** after **`HTTPFETCH`** to **`/boing_sheet.png`**. Prefer **matching** root paths:

```basic
LOADSPRITE 1, "/boing_sheet.png", 64, 64
LOADSPRITE 2, "/boing_shadow.png"
```

(See **`docs/wasm-assets-loadsprite-http.md`**.)

## Future / plugin extension

A dedicated **“canvas”** block could enqueue **`basic-canvas.js`** / **`basic-canvas.wasm`** and reuse **`canvas.html`** logic; the current plugin would need new assets and **`frontend-init.js`** changes. Until then, **iframe** or **custom HTML** are the supported paths for sprite demos.

## Related

- **`docs/ide-retrogamecoders-canvas-integration.md`** — Module, Asyncify, MEMFS, `basic_load_and_run_gfx`
- **`docs/wasm-assets-loadsprite-http.md`** — `HTTPFETCH`, CORS, `LOADSPRITE` paths
- **`wordpress/rgc-basic-tutorial-block/README.md`** — terminal embed only
