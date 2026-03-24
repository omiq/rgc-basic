# CBM-BASIC in the Browser

## Build (requires Emscripten)

```bash
# From project root
make basic-wasm
```

Requires [Emscripten](https://emscripten.org/) (emsdk). Install and activate, then run the above.

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
- **PRINT** output appears below.
- **INPUT** uses the browser's built-in `prompt()` dialog (Emscripten default).
- **SYSTEM** and **EXEC$** are not available in the browser (return -1 / empty string).
- **OPEN/PRINT#/INPUT#** work via Emscripten's virtual filesystem. Use paths like `"out.txt"` (writes to virtual FS).

## API (for embedding)

The build uses the **classic** Emscripten loader (not `MODULARIZE`). Define `window.Module` **before** loading `basic.js`, then hook `onRuntimeInitialized`:

```html
<script>
  var Module = {
    onRuntimeInitialized: function () {
      Module.ccall('basic_apply_arg_string', 'number', ['string'], ['-petscii -palette c64']);
      Module.FS.writeFile('/program.bas', '10 PRINT "HI"\n20 END');
      Module.ccall('basic_load_and_run', null, ['string'], ['/program.bas']);
    }
  };
</script>
<script src="basic.js"></script>
```

`preRun` may call `FS.init(stdinFn, null, null)` for INPUT; in that scope `FS` is the Emscripten global (see `web/index.html`).

See `docs/browser-wasm-plan.md` for the full plan.
