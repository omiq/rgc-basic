# CBM-BASIC in the Browser

## Build (requires Emscripten)

```bash
# From project root
make basic-wasm          # terminal demo: web/index.html
make basic-wasm-canvas   # PETSCII canvas: web/canvas.html
```

Requires [Emscripten](https://emscripten.org/) (emsdk). Install and activate, then run the above.

The terminal build (`basic.js`) enables **Asyncify** (`emscripten_sleep`) so **INPUT**, **GET**, and **INKEY$** can block without freezing the tab; call `basic_load_and_run` with **`ccall(..., { async: true })`** so the returned Promise resolves when the program finishes. **`index.html`** exposes **Pause** / **Resume** (`Module.wasmPaused`) and **Stop** (`Module.wasmStopRequested`), same flags as the canvas demo. **`Module.wasmRunDone`** is set when `basic_load_and_run` finishes.

The **canvas** build (`basic-canvas.js`) links **`GFX_VIDEO`** (plus `gfx_canvas.c` for RGBA export). Use **`basic_load_and_run_gfx`** and **`wasm_gfx_render_rgba`** (see **`canvas.html`**). **`#OPTION columns 80`** in the program selects a **640×200** framebuffer (else 320×200). **`INPUT`** and **`GET`/`INKEY$`** use the **PETSCII canvas**: focus the canvas (click it), then type. Keys go to a **heap ring buffer** via **`DataView`** (see **`canvas.html`**). **Stop** sets **`Module.wasmStopRequested`** so the run can exit cooperatively. While waiting for **`GET`**, **`Module.wasmWaitingKey`** is `1` (green outline). **LOADSPRITE** / **DRAWSPRITE** are stubbed (no textures in WASM).

## Run

Serve the `web/` folder over HTTP (WASM has restrictions with `file://`):

```bash
cd web && python3 -m http.server 8080
# Or: npx serve web
# Then open http://localhost:8080
# Canvas build: http://localhost:8080/canvas.html
```

## Canvas build (`canvas.html`)

- **Run** calls `basic_load_and_run_gfx` (Asyncify). The interpreter renders the 40×25 (or 80×25) text screen into a shared **RGBA buffer**; the page’s `requestAnimationFrame` loop copies pixels to a `<canvas>` so the display **updates during** `SLEEP`, tight loops, and `INPUT` / `gfx_read_line` waits.
- **GET** / **INKEY$**: focus the canvas, then type. Keys go to `wasm_push_key` (and the gfx key queue when `GFX_VIDEO` is enabled).
- **Pause** / **Resume** set `Module.wasmPaused = 1` / `0`; the interpreter yields until you resume (canvas: framebuffer stops updating; terminal: interpreter stops advancing statements). **Stop** sets `Module.wasmStopRequested = 1` and clears pause. Checked in the main loop and at yield points (`NEXT`, `GOTO`, `SLEEP`, `INPUT` / key-wait idle).
- **Safari / some browsers**: WASM pointers can be **BigInt**; the page coerces them. If the canvas stays black, check the red **log** under the canvas for heap read errors, or use **Chrome/Firefox**. Ensure **Asyncify** is enabled in the build (`make basic-wasm-canvas`).

## Usage (terminal `index.html`)

- Edit the BASIC program in the textarea and click **Run**.
- **Interpreter options** on the page map to the same flags as the native binary (`-petscii`, `-palette`, `-charset`, `-columns`). Before each run the demo calls `basic_apply_arg_string` so PETSCII colours render in the output panel (ANSI → HTML).
- **PRINT** output appears in the output panel.
- **INPUT** on **`index.html`** uses the **inline field** under the output (not `prompt()`): `Module.onWasmNeedInputLine`, `Module.wasmInputLineText`, `Module.wasmInputLineReady`, and **`Module.wasmInputLabel`** from the string prompt. On **`canvas.html`**, **INPUT** is typed **on the PETSCII canvas** (same as **GET**): focus the canvas first.
- **PRINT** line breaks: the demo inserts **`<br>`** for newline characters in `Module.print` so `PRINT` without a trailing `;` advances to the next line in the panel.
- **Pause** / **Resume** / **Stop**: same **`Module.wasmPaused`** / **`Module.wasmStopRequested`** semantics as **`canvas.html`** (cooperative; checked each statement in the main loop and during waits).
- **GET** / **INKEY$**: click the output panel so it is focused, then type. Keys are sent with **`wasm_push_key`** (byte). While the interpreter waits for a key, **`Module.wasmWaitingKey`** is `1` (green outline in the demo).
- **SYSTEM** and **EXEC$** are not available in the browser (return -1 / empty string).
- **OPEN/PRINT#/INPUT#** work via Emscripten's virtual filesystem. Use paths like `"out.txt"` (writes to virtual FS).

## API (for embedding)

The build uses the **classic** Emscripten loader (not `MODULARIZE`). Define `window.Module` **before** loading `basic.js`, then hook `onRuntimeInitialized`:

```html
<script>
  var Module = {
    onRuntimeInitialized: function () {
      Module.onWasmNeedInputLine = function () { /* show your INPUT UI */ };
      Module.ccall('basic_apply_arg_string', 'number', ['string'], ['-petscii -palette c64']);
      Module.FS.writeFile('/program.bas', '10 PRINT "HI"\n20 END');
      Module.ccall('basic_load_and_run', null, ['string'], ['/program.bas'], { async: true })
        .then(function () { /* finished */ });
    }
  };
</script>
<script src="basic.js"></script>
```

- **`wasm_push_key(byte)`** — enqueue one byte for **GET** / **INKEY$** (exported C symbol `_wasm_push_key`).
- Do not rely on **`FS.init(stdin, …)`** for line input; the interpreter reads **INPUT** via **`wasm_read_input_line_blocking`** and Asyncify.

See `docs/browser-wasm-plan.md` for the full plan.
