# IDE integration: RGC-BASIC canvas WASM as a tool host

**Status:** **`basic_load_and_run_gfx`** is exported; IDE UI is up to the host application. Passing **`ARG$(1)`** from the browser host is not a separate C export on this branch — use a **fixed MEMFS path** the tool reads, **`HTTPFETCH`**, or generate a short **`.bas`** stub that assigns the path.

## Goal

Use the **`basic-canvas.wasm`** build to run small **utility programs** (image preview, asset validators, etc.) when the user selects a non-code file. The tool is a normal **`.bas`** file.

## URL vs local paths (LOADSPRITE, OPEN, etc.)

- **`LOADSPRITE`**, **`OPEN`**, and other file paths are resolved against the **Emscripten MEMFS** (and the sprite **base directory** for relative paths), i.e. **local/VFS paths** such as **`/preview.png`** or **`examples/foo.png`**.
- **HTTP/HTTPS URLs are not** passed directly to `fopen` / PNG decode in the sprite path. To load from the network, use **`HTTPFETCH(url$, "/memfs/path.png")`** (binary-safe) or **`HTTP$`** for small text responses, then **`LOADSPRITE 1, "/memfs/path.png"`** — **not** `LOADSPRITE "https://..."` out of the box.

## BASIC API for tool arguments (CLI / future host)

| Expression | Meaning |
|------------|---------|
| **`ARG$(0)`** | Path of the running **`.bas`** program (same as CLI). |
| **`ARG$(1)`** | First argument **after** the program path (native **`./basic tool.bas /path`**). |
| **`ARG$(2)`** | Second trailing argument. |
| **`ARGC()`** | Number of trailing arguments (not including the program path). |

**Canvas WASM today:** **`basic_load_and_run_gfx(path)`** runs with **no** trailing argv. Tools should **`LOADSPRITE 1, "/preview.png"`** (or another **fixed** path the IDE writes) or call **`HTTPFETCH`** to download, then load by path.

Example when the IDE always writes the asset to **`/preview.png`**:

```basic
REM IDE wrote /preview.png before Run
LOADSPRITE 1, "/preview.png"
REM ...
```

## WASM entry point: `basic_load_and_run_gfx`

The canvas build exports **`_basic_load_and_run_gfx`** (see **`Makefile`** `EXPORTED_FUNCTIONS`).

**C signature:**

```c
void basic_load_and_run_gfx(const char *path);
```

Loads the **`.bas`** at **`path`** (MEMFS), initializes video, runs **`run_program`** with **no** extra arguments, then sets **`Module.wasmGfxRunDone`**.

### JavaScript usage

```javascript
Module.ccall('basic_load_and_run_gfx', null, ['string'], ['/ide/tools/png_view.bas']);
```

Use **`ccall`** / **`cwrap`** with the **mangled** export name **`_basic_load_and_run_gfx`** (Emscripten default). Call with **`{ async: true }`** if using Asyncify features (**`INPUT`**, **`HTTP$`**, **`HTTPFETCH`**, etc.).

## IDE workflow (recommended)

1. **Bundle** tool programs under a fixed MEMFS prefix, e.g. **`/ide/tools/png_view.bas`**, at WASM startup (embed in JS or fetch once and **`FS.writeFile`**).
2. When the user **opens a `.png`** (or other asset): write bytes to a **fixed path** the tool expects (e.g. **`/preview.png`**) or use **`HTTPFETCH`** inside the tool.
3. **Focus** the canvas for **`INKEY$`** / **`GET`** if the tool uses them.
4. On **Stop** / **new file**, use **`wasmStopRequested`** / existing canvas controls before launching another tool.

## Related

- **`docs/http-vfs-assets.md`** — **`HTTPFETCH`**, binary **`OPEN`**, **`PUTBYTE`/`GETBYTE`**.
- **`docs/tutorial-embedding.md`**, **`web/vfs-helpers.js`** — VFS upload patterns.
- **`web/canvas.html`** — **`basic_load_and_run_gfx`**, pause/stop hooks.
