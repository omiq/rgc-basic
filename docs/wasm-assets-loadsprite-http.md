# Loading sprite and image assets over HTTP (canvas WASM / MEMFS)

**Audience:** Authors embedding RGC-BASIC **canvas WASM** programs (e.g. WordPress posts, tutorials, IDE) who want PNGs or other files that live on **HTTP/HTTPS**, not only files uploaded to the virtual filesystem by hand.

## What does *not* work

**`LOADSPRITE slot, "https://example.com/ball.png"`** — **Invalid.**  
Sprite and file paths are resolved against the **Emscripten MEMFS** (and the program’s base directory for relative paths). The interpreter does **not** pass arbitrary URLs to `fopen` or the PNG decoder.

The same applies to **`OPEN`**, **`LOAD` INTO**, and other file-based features: they expect **VFS paths** like **`/boing_sheet.png`** or **`assets/ball.png`**, not **`https://...`**.

## Option A — BASIC only: `HTTPFETCH` then `LOADSPRITE`

**`HTTPFETCH url$, path$`** downloads the **raw response body** to a **MEMFS path** (browser WASM: `fetch` + `FS.writeFile`). Then use that path in **`LOADSPRITE`**.

Example (check **`HTTPSTATUS()`** after each fetch):

```basic
U1$ = "https://example.com/wp-content/uploads/boing_sheet.png"
U2$ = "https://example.com/wp-content/uploads/boing_shadow.png"

IF HTTPFETCH(U1$, "/boing_sheet.png") = 0 OR HTTPSTATUS() <> 200 THEN PRINT "fetch failed "; HTTPSTATUS(): END
IF HTTPFETCH(U2$, "/boing_shadow.png") = 0 OR HTTPSTATUS() <> 200 THEN PRINT "fetch 2 failed "; HTTPSTATUS(): END

LOADSPRITE 1, "/boing_sheet.png", 64, 64
LOADSPRITE 2, "/boing_shadow.png"
```

- Use **consistent** paths: whatever you pass to **`HTTPFETCH`** as the second argument is what **`LOADSPRITE`** should use.
- **`HTTPFETCH`** is **async** (Asyncify); the runtime flushes **`PRINT`** before blocking so UI can update (see **`CHANGELOG`** / **`web/README.md`**).

### CORS (required in the browser)

**`HTTPFETCH`** uses the browser’s **`fetch`**. The **server that hosts the PNG** must allow your **page origin** via **CORS** (`Access-Control-Allow-Origin`), or the request fails and **`HTTPSTATUS()`** may be **0**.

Typical setups:

- Assets on the **same hostname** as the blog post (e.g. WordPress **Media Library**) — often same-origin, no extra CORS.
- Assets on a **CDN or another domain** — that server must send CORS headers allowing your site, or use Option B.

## Option B — Host JavaScript writes MEMFS (no HTTP in BASIC)

If CORS is awkward or you already load files in the page:

```javascript
// After fetch(blob) or from Media Library URL your JS controls:
const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer());
Module.FS.writeFile('/boing_sheet.png', bytes);
```

Then in BASIC:

```basic
LOADSPRITE 1, "/boing_sheet.png", 64, 64
```

See **`web/vfs-helpers.js`** and **`docs/tutorial-embedding.md`** for upload helpers.

## Terminal vs canvas builds

- **`LOADSPRITE`**, **`SCREEN 1`**, bitmap **`LINE`**, etc. require **basic-gfx** (native) or **`basic-canvas.wasm`** (browser), not the **terminal-only** `basic.js` / **`basic-modular`** embed.
- Tutorials that only mount the **modular terminal** interpreter cannot run this demo until the host loads the **canvas** build and exposes the same **MEMFS** + run entry points (see **`docs/ide-retrogamecoders-canvas-integration.md`** if you integrate with the Retro Game Coders IDE).

## Large responses and strings

- **`HTTP$`** returns the body as a **string** — fine for JSON/text; large binaries can hit **`MAXSTR`** — use **`HTTPFETCH`** for PNGs.
- Set **`#OPTION maxstr 4096`** (or as needed) when parsing big JSON with **`HTTP$`** (see **`docs/http-vfs-assets.md`**).

## Related

- **`docs/http-vfs-assets.md`** — **`HTTPFETCH`**, binary **`OPEN`**, **`PUTBYTE`/`GETBYTE`**
- **`docs/ide-wasm-tools.md`** — **`basic_load_and_run_gfx`**, **`ARG$`**, tools on MEMFS
- **`docs/tutorial-embedding.md`**, **`web/README.md`** — WASM builds, CORS, **`vfs-helpers`**
