# IDE integration: RGC-BASIC canvas WASM as a tool host

**Status:** WASM exports **`basic_load_and_run_gfx`** and **`basic_load_and_run_gfx_argline`** are implemented; IDE UI is up to the host application. Use **`HTTPFETCH`** when the tool should download an asset into MEMFS without JavaScript.

## Goal

Use the **`basic-canvas.wasm`** build to run small **utility programs** (image preview, asset validators, etc.) when the user selects a non-code file. The tool is a normal **`.bas`** file. The IDE can pass **paths** as **command-line arguments** (**`ARG$(1)`** …) via **`basic_load_and_run_gfx_argline`**, or write to a **fixed MEMFS path** and call **`basic_load_and_run_gfx`** alone.

## URL vs local paths (LOADSPRITE, OPEN, etc.)

- **`LOADSPRITE`**, **`OPEN`**, and other file paths are resolved against the **Emscripten MEMFS** (and the sprite **base directory** for relative paths), i.e. **local/VFS paths** such as **`/preview.png`** or **`examples/foo.png`**.
- **HTTP/HTTPS URLs are not** passed directly to `fopen` / PNG decode in the sprite path. To load from the network, use **`HTTPFETCH(url$, "/memfs/path.png")`** (binary-safe) or **`HTTP$`** for small text responses, then **`LOADSPRITE 1, "/memfs/path.png"`** — **not** `LOADSPRITE "https://..."` out of the box.

## BASIC API for tool arguments

| Expression | Meaning |
|------------|---------|
| **`ARG$(0)`** | Path of the running **`.bas`** program (same as CLI). |
| **`ARG$(1)`** | First argument **after** the program path. |
| **`ARG$(2)`** | Second trailing argument. |
| **`ARGC()`** | Number of trailing arguments (not including the program path). |

Example tool snippet (IDE wrote **`/preview.png`** or passed it as **`ARG$(1)`**):

```basic
REM With argline: F$ = ARG$(1)
F$ = ARG$(1)
IF F$ = "" THEN PRINT "No file": END
LOADSPRITE 1, F$
REM ...
```

## WASM entry point: `basic_load_and_run_gfx`

The canvas build exports **`_basic_load_and_run_gfx`** (see **`Makefile`** `EXPORTED_FUNCTIONS`).

**C signature:**

```c
void basic_load_and_run_gfx(const char *path);
```

Loads the **`.bas`** at **`path`** (MEMFS), initializes video, runs **`run_program`** with **no** extra arguments (`ARGC()` = 0), then sets **`Module.wasmGfxRunDone`**.

### JavaScript usage

```javascript
Module.ccall('basic_load_and_run_gfx', null, ['string'], ['/ide/tools/png_view.bas']);
```

Use **`ccall`** with **`{ async: true }`** when using Asyncify (**`INPUT`**, **`HTTP$`**, **`HTTPFETCH`**, etc.).

## WASM entry point: `basic_load_and_run_gfx_argline`

The canvas build exports **`_basic_load_and_run_gfx_argline`** (see **`Makefile`** `EXPORTED_FUNCTIONS`).

**C signature:**

```c
int basic_load_and_run_gfx_argline(const char *argline);
```

**Behaviour:**

1. Parses **`argline`** into tokens (space-separated; **double- or single-quoted** tokens may contain spaces).
2. **First token** = path to the **`.bas`** file (must exist on **MEMFS**).
3. Remaining tokens = **`argv`** for **`run_program(bas_path, argc-1, argv+1)`**, so **`ARG$(1)`** = first extra token, etc.
4. Calls **`load_program`**, **`wasm_gfx_set_video`**, **`run_program`**, then refreshes the canvas framebuffer.
5. Returns **0** on success, **-1** on parse error (stderr hint).

**No-args case:** If only one token is present, behaviour matches **`basic_load_and_run_gfx(bas_path)`** (`ARGC()` = 0).

### Example `argline` strings

| `argline` | `ARG$(0)` | `ARG$(1)` |
|-----------|-----------|-----------|
| `"/ide/tools/view.bas" "/tmp/preview.png"` | `/ide/tools/view.bas` | `/tmp/preview.png` |
| `/ide/tools/view.bas /tmp/preview.png` | (same) | (same) — **only if paths have no spaces** |

### JavaScript usage (pseudo-code)

```javascript
const bas = '/ide/png_view.bas';
const png = '/preview.png';
const rc = Module.ccall(
  'basic_load_and_run_gfx_argline',
  'number',
  ['string'],
  ['"' + bas + '" "' + png + '"'],
  { async: true }
);
```

Use the **mangled** export name **`_basic_load_and_run_gfx_argline`** (Emscripten default).

## IDE workflow (recommended)

1. **Bundle** tool programs under a fixed MEMFS prefix, e.g. **`/ide/tools/png_view.bas`**, at WASM startup (**`FS.writeFile`** / embed).
2. When the user **opens a `.png`** (or other asset):
   - **Option A:** Write bytes to **`/preview.png`**, then **`basic_load_and_run_gfx_argline`** with the tool **`.bas`** and **`/preview.png`** as **`ARG$(1)`**.
   - **Option B:** Run a tool that calls **`HTTPFETCH`** to download into MEMFS, then **`LOADSPRITE`** / **`OPEN`**.
3. **Focus** the canvas for **`INKEY$`** / **`GET`** if the tool uses them.
4. On **Stop** / **new file**, use **`wasmStopRequested`** / existing canvas controls before launching another tool.

## Host `EXEC$` / `SYSTEM` (IDE tools, editors, compilers)

For actions that are not HTTP or MEMFS alone (e.g. uppercase selection, search/replace in the editor buffer, “run compiler”), implement **`Module.rgcHostExec`** on the same **`Module`** instance as the WASM build. **`EXEC$`** receives the string you define (e.g. **`ide:uppercase`**); your handler runs in JS and returns **`{ stdout, exitCode }`**. Works in **terminal** and **canvas** Asyncify builds. Full contract: **`docs/wasm-host-exec.md`**.

## Related

- **`docs/wasm-host-exec.md`** — **`EXEC$` / `SYSTEM`** host hook (testing checklist).
- **`docs/http-vfs-assets.md`** — **`HTTPFETCH`**, binary **`OPEN`**, **`PUTBYTE`/`GETBYTE`**.
- **`docs/tutorial-embedding.md`**, **`web/vfs-helpers.js`** — VFS upload patterns.
- **`web/canvas.html`** — **`basic_load_and_run_gfx`**, pause/stop hooks.
- **`CHANGELOG.md`** — **`basic_load_and_run_gfx_argline`**, **`HTTPFETCH`**.
