# Integrating CBM-BASIC canvas WASM into an online IDE

This guide is written for hosts such as **[Retro Game Coders IDE](https://ide.retrogamecoders.com)** that want to run **Commodore-style BASIC** in an embedded frame with **Play / Pause / Stop**, while pushing **program source** and **binary assets** (PNGs, data files) into the interpreter.

The reference implementation is the upstream demo **`web/canvas.html`** plus the build target **`make basic-wasm-canvas`**, which produces:

| File | Purpose |
|------|---------|
| `basic-canvas.js` | Emscripten loader (classic `Module`, not `MODULARIZE`) |
| `basic-canvas.wasm` | Interpreter + `GFX_VIDEO` (PETSCII, `SCREEN 1` bitmap, PNG sprites) |

Related docs: **`docs/gfx-canvas-parity.md`** (feature parity with `basic-gfx`), **`web/README.md`** (browser overview).

---

## 1. What you are embedding

- **Display**: 320×200 or 640×200 logical pixels (40×25 or 80×25 text cells at 8×8 px). The framebuffer is exported as **RGBA** in WASM linear memory; your page copies it to a `<canvas>` in a **`requestAnimationFrame`** loop.
- **Execution model**: **Asyncify**. The entrypoint **`basic_load_and_run_gfx`** must be invoked with **`ccall(..., { async: true })`** so the returned Promise resolves when the program ends (or errors). The tab stays responsive during `SLEEP`, `INPUT`, and key waits.
- **Virtual filesystem**: Emscripten **MEMFS** (`Module.FS`). `OPEN` / `PRINT#` / `INPUT#` and **`LOADSPRITE "file.png"`** read paths under this FS. Nothing touches the user’s real disk unless you copy bytes into MEMFS yourself.

---

## 2. Deploy the build on your origin

1. From the [cbm-basic](https://github.com/omiq/cbm-basic) repo: **`make basic-wasm-canvas`**.
2. Publish **`basic-canvas.js`** and **`basic-canvas.wasm`** under a stable URL on **the same site** as your IDE (or enable **CORS** on the asset host; many setups keep JS+WASM on the IDE origin to avoid COOP/CORS issues).
3. Optional but useful: copy **`web/vfs-helpers.js`** if you want reuse of upload/download helpers (see §8).

**Critical: cache pairing.** The `.js` and `.wasm` **must stay in sync**. If the browser caches an old `.js` with a new `.wasm` (or the reverse), you can see errors such as **`ASM_CONSTS[code] is not a function`**. Mitigation used in `canvas.html`:

- Use one **cache-bust** query string for **both** script and WASM, e.g. `?cb=<buildIdOrTimestamp>` on **`basic-canvas.js`** and the same value inside **`locateFile`** for **`basic-canvas.wasm`**.

---

## 3. Minimal HTML shell (iframe-friendly)

Your IDE can render a child page or component that:

1. Defines **`window.Module`** *before* loading **`basic-canvas.js`**.
2. Loads the script (with matching **`?cb=`** for wasm).
3. On **`Module.onRuntimeInitialized`**, enables **Run** and wires **Play / Pause / Stop**.

Skeleton:

```html
<canvas id="screen" width="320" height="200" tabindex="0"></canvas>
<button type="button" id="run">Run</button>
<button type="button" id="pause" disabled>Pause</button>
<button type="button" id="resume" disabled>Resume</button>
<button type="button" id="stop" disabled>Stop</button>

<script>
(function () {
  var ASSET_CB = '2026-03-25'; // or build id — must match .js and .wasm URLs

  var Module = {
    canvasAssetCb: ASSET_CB,
    locateFile: function (path) {
      if (path.endsWith('.wasm')) {
        return 'https://ide.retrogamecoders.com/cbm-basic/basic-canvas.wasm?cb=' + encodeURIComponent(ASSET_CB);
      }
      return path;
    },
    printErr: function (t) { console.error('[cbm-basic]', t); },
    onWasmNeedInputLine: function () {
      /* Show your INPUT UI; see §6 */
    },
    onRuntimeInitialized: function () {
      /* Enable Run; attach button handlers — see §5 */
    }
  };
  window.Module = Module;

  var s = document.createElement('script');
  s.src = 'https://ide.retrogamecoders.com/cbm-basic/basic-canvas.js?cb=' + encodeURIComponent(ASSET_CB);
  s.async = false;
  document.body.appendChild(s);
})();
</script>
```

Adjust base URLs to match where you host the files (e.g. under `/cbm-basic/` on the IDE domain).

---

## 4. Sending the BASIC program and assets

### 4.1 Program text

Before each run, write the editor buffer to a **fixed path** the loader uses in examples:

```javascript
Module.FS.writeFile('/program.bas', sourceString);
```

Then run (see §5) with path **`/program.bas`**.

### 4.2 Assets (PNGs, sequential files, etc.)

`LOADSPRITE 0,"hero.png"` resolves paths like the **native** gfx build: relative paths are relative to the **directory of the loaded `.bas` file**. For **`/program.bas`**, place files at the **MEMFS root** with the same basename:

```javascript
Module.FS.writeFile('/hero.png', new Uint8Array(pngBytes));
```

If your BASIC uses **`LOADSPRITE 0,"gfx/hero.png"`**, create directories:

```javascript
Module.FS.mkdir('/gfx');
Module.FS.writeFile('/gfx/hero.png', new Uint8Array(pngBytes));
```

**Flow from the IDE:**

1. User selects or uploads assets in your UI.
2. Your app reads each file as **`ArrayBuffer`** / **`Uint8Array`**.
3. Before **`basic_load_and_run_gfx`**, call **`Module.FS.writeFile('/…', bytes)`** for each asset.
4. Ensure **`LOADSPRITE` / `OPEN` paths** in the program match those MEMFS paths.

For a minimal end-to-end sample, see **`examples/gfx_canvas_demo.bas`** and **`examples/gfx_canvas_demo.png`** in the cbm-basic repo.

### 4.3 Clearing between runs (optional)

MEMFS persists for the lifetime of the WASM module. To avoid stale files:

- **`Module.FS.unlink('/old.png')`** for known paths, or
- Re **`writeFile`** the same paths each run (overwrites), or
- Tear down and reload the entire module (heavy).

Sprite textures are reset when the interpreter starts a gfx run internally; still overwrite or remove MEMFS files if the user changes assets without reloading the page.

---

## 5. Run, Pause, Stop (Play semantics)

### Interpreter flags

Build a flag string like the CLI (same as **`basic_apply_arg_string`** on native):

```javascript
var flags = '-petscii -palette ansi -charset upper -columns 40';
var rc = Module.ccall('basic_apply_arg_string', 'number', ['string'], [flags]);
if (rc !== 0) { /* invalid options */ }
```

Common options: **`-petscii`**, **`-petscii-plain`**, **`-charset upper|lower`**, **`-palette ansi|c64`**, **`-columns 40`** or **`-columns 80`**. Program lines **`#OPTION …`** in the `.bas` file are applied at load time as well.

### Start run (Play)

```javascript
Module.wasmStopRequested = 0;
Module.wasmPaused = 0;
Module.FS.writeFile('/program.bas', editorSource);

Module.ccall('basic_load_and_run_gfx', null, ['string'], ['/program.bas'], { async: true })
  .catch(function (e) { console.error(e); })
  .finally(function () {
    Module.wasmPaused = 0;
    /* re-enable Run, disable Pause/Stop, stop rAF if you gate on "running" */
  });
```

Set **`Module.wasmGfxRunDone = 0`** before run and **`1`** after if you want to mirror the reference page (the C runtime sets these around **`basic_load_and_run_gfx`**).

### Pause / Resume

Cooperative flags checked inside the interpreter and during waits:

```javascript
// Pause
Module.wasmPaused = 1;

// Resume
Module.wasmPaused = 0;
```

While paused, the WASM thread sleeps in yield loops; the framebuffer stops updating until resume.

### Stop

```javascript
Module.wasmStopRequested = 1;
Module.wasmPaused = 0;
```

The program exits from the main loop / blocking waits as soon as the next check runs. You still wait for the **`basic_load_and_run_gfx`** Promise to settle in **`finally`**.

---

## 6. Display loop (iframe “frame”)

The reference copies **`wasm_gfx_rgba_ptr()`** through **`HEAPU8`** (or **`wasmMemory.buffer`**) when **`wasm_gfx_rgba_version_read()`** changes. After each copy, **`Module.wasmGfxFbW`** and **`Module.wasmGfxFbH`** are set (320 or 640 × 200). **`Module.wasmGfxBorderPx`**, **`wasmGfxBorderColorIdx`**, and **`wasmGfxContentBgIdx`** support **`#OPTION border`** padding drawn outside the framebuffer in JS.

Reuse the logic in **`web/canvas.html`** functions **`copyRgbaFromWasm`** and the **`requestAnimationFrame`** loop. Keep **`wasmRunPending`** (or equivalent) **true** from Run until **`finally`**, so the canvas keeps polling during execution.

---

## 7. Keyboard: `GET` / `INKEY$` and `INPUT`

- **`GET` / `INKEY$`**: Focus your canvas; on `keydown`, call  
  **`Module.ccall('wasm_push_key', null, ['number'], [byte])`**.  
  Reference uses keyCode 13 → byte 13, printable ASCII → low 8 bits. While waiting, **`Module.wasmWaitingKey === 1`** (optional UI hint).
- **`INPUT`**: Implement **`Module.onWasmNeedInputLine`**. When called, show a line field; on Enter set **`Module.wasmInputLineText`** to the string, **`Module.wasmInputLineReady = 1`**, and return focus to the canvas if desired. The C runtime reads these properties.

---

## 8. Optional: upload UX

The project ships **`web/vfs-helpers.js`** with **`CbmVfsHelpers.vfsUploadFiles(Module, fileList)`** and **`vfsMountUI`** for a small toolbar. You can load it on your IDE page and call upload after **`onRuntimeInitialized`**, or implement your own file picker that **`FS.writeFile`**s into MEMFS.

---

## 9. Embedding in an iframe at ide.retrogamecoders.com

Typical pattern:

1. **Route**: e.g. **`/embed/cbm-basic-canvas`** serves the minimal shell (canvas + controls + `Module` bootstrap).
2. **Parent IDE**: `postMessage` to the iframe with **`{ type: 'RUN', source: '...', files: { '/a.png': ArrayBuffer, ... }, flags: '-petscii ...' }`**. The iframe **`message`** listener writes **`FS`**, applies flags, calls **`basic_load_and_run_gfx`**.
3. **Sandbox**: If you use **`sandbox`** on the iframe, allow **`allow-scripts`**, **`allow-same-origin`** (if assets are same-origin), and ensure **`postMessage`** origins are validated both ways.

Use **HTTPS** for WASM; mixed content will block the module.

---

## 10. Debugging

- Append **`?debug=1`** to your embed URL (as in **`canvas.html`**) to enable verbose console logging and optional stack dumps if exports are present.
- If the canvas stays black, check **`printErr`** output and verify **`HEAPU8`** / **`wasm_gfx_rgba_ptr`** copy (see **`web/canvas.html`** diagnostics).

---

## 11. Automated test reference

Upstream CI runs **`make wasm-canvas-test`** (`tests/wasm_browser_canvas_test.py`): it loads **`canvas.html`**, injects programs, fetches PNGs into MEMFS, and samples pixels. Use it as a behavioral checklist when porting the same flow into your IDE.

---

## Summary checklist

| Step | Action |
|------|--------|
| 1 | Host **`basic-canvas.js`** + **`basic-canvas.wasm`** with matched **`?cb=`** |
| 2 | Predeclare **`Module`**, then load the script |
| 3 | On init: wire canvas rAF + **`copyRgbaFromWasm`** |
| 4 | On Run: **`basic_apply_arg_string`**, **`FS.writeFile('/program.bas', …)`**, assets to MEMFS paths |
| 5 | **`ccall('basic_load_and_run_gfx', …, { async: true })`** |
| 6 | Pause **`Module.wasmPaused = 1`**, Stop **`Module.wasmStopRequested = 1`** |
| 7 | Implement **`onWasmNeedInputLine`** + **`wasm_push_key`** for I/O |

This matches how **`web/canvas.html`** integrates the canvas build and is suitable for a retro IDE frame with editor-driven source and asset injection.
