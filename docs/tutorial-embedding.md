# Embedding RGC-BASIC in tutorials (multiple instances per page)

This guide explains how to run **one or more** terminal-style BASIC interpreters in HTML (e.g. documentation, course pages, or a custom IDE). The full-page demos `web/index.html` and `web/canvas.html` use a **single** global `Module` and are not suitable for multiple copies on the same document. For tutorials, use the **modular** WASM build plus **`web/tutorial-embed.js`**.

## What you need on the server

From the project root, after installing [Emscripten](https://emscripten.org/) (emsdk):

```bash
make basic-wasm-modular
```

This produces:

| File | Role |
|------|------|
| `web/basic-modular.js` | Emscripten loader with `MODULARIZE=1`; exports `createBasicModular` |
| `web/basic-modular.wasm` | Same interpreter as `basic.wasm` (terminal I/O, not canvas PETSCII) |
| `web/tutorial-embed.js` | Helper that mounts UI + one WASM instance per container |
| `web/vfs-helpers.js` | Shared **upload/download** helpers for `Module.FS` (loaded automatically by tutorial embeds) |
| `web/tutorial-example.html` | Minimal page with **two** embeds (smoke test reference) |

Serve the `web/` directory over **HTTP** (WASM is blocked on many browsers for `file://`).

Optional check:

```bash
make wasm-tutorial-test   # headless Chromium; needs Playwright (see tests/requirements-wasm.txt)
```

## Quick start (one embed)

```html
<div id="lesson1"></div>
<script src="tutorial-embed.js"></script>
<script>
  RgcBasicTutorialEmbed.mount(document.getElementById('lesson1'), {
    program: '10 PRINT "Hello from the tutorial"\n20 END\n'
  });
</script>
```

(`CbmBasicTutorialEmbed` remains as a deprecated alias for one release.)

Requirements:

1. **`tutorial-embed.js`** must be loadable (same folder as `basic-modular.js` by default, or set `baseUrl`).
2. **`basic-modular.js`** and **`basic-modular.wasm`** must live in that **base URL** directory.
3. **`vfs-helpers.js`** in the same folder (for **Upload to VFS** / **Download from VFS** on each embed). If the file is missing, embeds still run; VFS buttons are omitted.

The script loads `basic-modular.js` once (first mount) and reuses `createBasicModular` for every subsequent mount.

## Virtual filesystem: upload and export

**Full demos** `web/index.html` and `web/canvas.html` include **Upload to VFS** and **Download from VFS** (via `vfs-helpers.js`). **Tutorial embeds** load `vfs-helpers.js` from `baseUrl` when `showVfsTools` is true (default).

Programmatic API (after `vfs-helpers.js` is on the page):

```javascript
// Upload browser files → MEMFS at /filename (creates parent dirs)
RgcVfsHelpers.vfsUploadFiles(Module, fileList, function (msg, err) { console.log(msg); });

// Download one file from VFS
RgcVfsHelpers.vfsExportFile(Module, '/out.txt');

// Or mount the default toolbar into a div
RgcVfsHelpers.vfsMountUI(document.getElementById('vfs'), Module, {
  pathDefault: '/out.txt',
  onStatus: function (m, isErr) { ... }
});
```

(`CbmVfsHelpers` is a deprecated alias.)

Paths must be single-segment filenames or `/path/...` with **no `..`**. Export uses a temporary object URL (browser download).

## Multiple embeds on one page

Give each snippet its own container and call `mount` once per container:

```html
<div id="exA"></div>
<div id="exB"></div>
<script src="tutorial-embed.js"></script>
<script>
  RgcBasicTutorialEmbed.mount(document.getElementById('exA'), {
    program: '10 PRINT "Exercise A"\n20 END\n'
  });
  RgcBasicTutorialEmbed.mount(document.getElementById('exB'), {
    program: '10 PRINT "Exercise B"\n20 END\n'
  });
</script>
```

Each embed gets its own **virtual filesystem** and **Asyncify** state; they do not share variables or `DATA` with each other.

## `mount(container, options)` options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `baseUrl` | string | directory of `tutorial-embed.js` | URL prefix ending in `/` where `basic-modular.js` and `basic-modular.wasm` are served |
| `modularScript` | string | `'basic-modular.js'` | Name of the modular loader script |
| `wasmFile` | string | `'basic-modular.wasm'` | WASM filename if you rename it |
| `program` | string | `10 PRINT "HELLO"\n20 END\n` | Initial source (also shown in the textarea if `showEditor` is true) |
| `flags` | string | `'-petscii -palette ansi -charset upper'` | Passed to `basic_apply_arg_string` (same as CLI) |
| `showEditor` | boolean | `true` | If false, hides the textarea; program is fixed to `program` |
| `showPauseStop` | boolean | `true` | If false, only **Run** is shown (no Pause/Resume/Stop) |
| `showVfsTools` | boolean | `true` | VFS upload/download row (skip if `vfs-helpers.js` unavailable) |
| `vfsExportPath` | string | `'/out.txt'` | Default path in the download field |
| `editorMinHeight` | string | `'120px'` | CSS min-height for textarea |
| `outputMinHeight` | string | `'100px'` | CSS min-height for output panel |

## Returned API (`Promise`)

`mount` resolves to an object:

| Method / property | Description |
|-------------------|-------------|
| `run()` | Programmatically triggers the same action as **Run** |
| `resetOutput()` | Clears the output div |
| `setProgram(src)` / `getProgram()` | Read/write editor text (no-op for program if `showEditor` is false) |
| `destroy()` | Removes DOM and sets stop flag (does not unload WASM memory aggressively; avoid mounting thousands per page) |
| `getModule()` | Raw Emscripten `Module` (advanced: `ccall`, `FS`, etc.) |

Example:

```javascript
RgcBasicTutorialEmbed.mount(el, { program: '10 END\n' }).then(function (api) {
  document.getElementById('rerun').onclick = function () {
    api.resetOutput();
    api.run();
  };
});
```

## User interaction (INPUT, GET, INKEY$)

Same behavior as `web/index.html`:

- **INPUT**: an inline row appears under the output; user types and presses Enter.
- **GET** / **INKEY$**: user focuses the **output** panel (click it), then types; keys go to `wasm_push_key`.
- The output panel shows a **green outline** while `wasmWaitingKey` is set (waiting for a key).

## Styling

The helper adds the class **`rgc-tutorial-embed`** on the container and uses BEM-like classes:

- `rgc-tutorial-program` — textarea  
- `rgc-tutorial-toolbar` — button row  
- `rgc-tutorial-output` — output  
- `rgc-tutorial-input-row` — INPUT row  

Override these in your site CSS. The example page `tutorial-example.html` shows a minimal border.

## Deploy paths and caching

- Put **`basic-modular.js`** and **`basic-modular.wasm`** in the **same directory** (Emscripten’s default `locateFile` expects that).
- After upgrading the interpreter, bump a cache query on **both** files or rename them (same issue as `canvas.html` + mismatched JS/WASM).
- If your tutorial lives in a subdirectory, set **`baseUrl`** to the folder that contains the modular assets, e.g.  
  `baseUrl: '/assets/rgc-basic/'`

## Canvas (PETSCII) tutorials

The modular build is **terminal output only** (like `index.html`). The **canvas** build (`basic-canvas.js`) is still the **classic** single-`Module` loader. For multiple PETSCII canvases on one page you would need a separate **MODULARIZE** build of `basic-wasm-canvas` (not shipped yet). For now, use **one** `iframe` per canvas demo, each pointing at `canvas.html` (or a thin wrapper), or one canvas per page.

## Security and limits

- Programs run **in the user’s browser** with the same trust model as the main demos.
- Each instance allocates WASM memory (~32 MiB initial for modular build). Use a **reasonable number** of embeds per page.
- `SYSTEM` / `EXEC$` are unavailable in the browser build (same as `index.html`).

## Files to copy for a static site

Minimum for tutorial embeds:

- `basic-modular.js`
- `basic-modular.wasm`
- `tutorial-embed.js`
- `vfs-helpers.js` (optional but recommended for OPEN/PRINT# workflows)

Optional:

- `tutorial-example.html` — reference layout  
- `docs/tutorial-embedding.md` — this guide  

The CI artifact tarball also includes these when you download **rgc-basic-wasm** from Actions.
