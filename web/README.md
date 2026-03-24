# CBM-BASIC in the Browser

## Build (requires Emscripten)

```bash
# From project root
make basic-wasm
# Optional: PETSCII canvas (GfxVideoState, 40×25; POKE/PEEK screen, INKEY$; no Raylib/sprites)
make basic-wasm-canvas
```

Requires [Emscripten](https://emscripten.org/) (emsdk). Install and activate, then run the above.

The terminal build (`basic.js`) enables **Asyncify** (`emscripten_sleep`) so **INPUT**, **GET**, and **INKEY$** can block without freezing the tab; call `basic_load_and_run` with **`ccall(..., { async: true })`** so the returned Promise resolves when the program finishes.

The **canvas** build (`basic-canvas.js`) links **`GFX_VIDEO`** (plus `gfx_canvas.c` for RGBA export). Use **`basic_load_and_run_gfx`** and **`wasm_gfx_render_rgba`** (see **`canvas.html`**). **`INPUT`** and **`GET`/`INKEY$`** use the **PETSCII canvas**: focus the canvas (click it), then type. The demo pushes key bytes to **`Module._wasmKeyJsQueue`** (do not **`ccall('wasm_push_key')` from key handlers** while the async run is suspended — Asyncify deadlock). **`wasm_push_key`** is still fine for programmatic keys when the interpreter is not inside a sleep. While waiting for **`GET`**, **`Module.wasmWaitingKey`** is `1` (green outline). **LOADSPRITE** / **DRAWSPRITE** are stubbed (no textures in WASM).

## Run

Serve the `web/` folder over HTTP (WASM has restrictions with `file://`):

```bash
cd web && python3 -m http.server 8080
# Or: npx serve web
# Then open http://localhost:8080
# Canvas PETSCII: http://localhost:8080/canvas.html (load basic-canvas.js)
```

## Usage

- Edit the BASIC program in the textarea and click **Run**.
- **Interpreter options** on the page map to the same flags as the native binary (`-petscii`, `-palette`, `-charset`, `-columns`). Before each run the demo calls `basic_apply_arg_string` so PETSCII colours render in the output panel (ANSI → HTML).
- **PRINT** output appears in the output panel.
- **INPUT** on **`index.html`** uses the **inline field** under the output (not `prompt()`): `Module.onWasmNeedInputLine`, `Module.wasmInputLineText`, `Module.wasmInputLineReady`, and **`Module.wasmInputLabel`** from the string prompt. On **`canvas.html`**, **INPUT** is typed **on the PETSCII canvas** (same as **GET**): focus the canvas first.
- **PRINT** line breaks: the demo inserts **`<br>`** for newline characters in `Module.print` so `PRINT` without a trailing `;` advances to the next line in the panel.
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
