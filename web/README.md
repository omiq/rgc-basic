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
- **PRINT** output appears below.
- **INPUT** uses the browser's built-in `prompt()` dialog (Emscripten default).
- **SYSTEM** and **EXEC$** are not available in the browser (return -1 / empty string).
- **OPEN/PRINT#/INPUT#** work via Emscripten's virtual filesystem. Use paths like `"out.txt"` (writes to virtual FS).

## API (for embedding)

```javascript
Basic().then(function(Module) {
  Module.FS.writeFile('/program.bas', '10 PRINT "HI"\n20 END');
  Module._basic_load_and_run('/program.bas');
});
```

See `docs/browser-wasm-plan.md` for the full plan.
