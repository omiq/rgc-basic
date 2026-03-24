# CBM-BASIC in the Browser

## Build (requires Emscripten)

```bash
# From project root
make basic-wasm
```

Requires [Emscripten](https://emscripten.org/) (emsdk). Install and activate, then run the above.

The build enables **Asyncify** (`emscripten_sleep`) so **INPUT**, **GET**, and **INKEY$** can block without freezing the tab; call `basic_load_and_run` with **`ccall(..., { async: true })`** so the returned Promise resolves when the program finishes.

## Run

Serve the `web/` folder over HTTP (WASM has restrictions with `file://`):

```bash
cd web && python3 -m http.server 8080
# Or: npx serve web
# Then open http://localhost:8080
```

## Usage

- Edit the BASIC program in the textarea and click **Run**.
- **Interpreter options** on the page map to the same flags as the native binary (`-petscii`, `-palette`, `-charset`, `-columns`). Before each run the demo calls `basic_apply_arg_string` so PETSCII colours render in the output panel (ANSI → HTML).
- **PRINT** output appears in the output panel.
- **INPUT** uses the **inline field** under the output (not `prompt()`). The demo sets `Module.onWasmNeedInputLine` to show the field and focus it; submitting sets `Module.wasmInputLineText` and `Module.wasmInputLineReady = 1`. **`Module.wasmInputLabel`** is set to the prompt string from **`INPUT "Hello";`** (or **`INPUT`** if there is no string prompt).
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
