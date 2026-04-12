# IDE integration: RGC-BASIC canvas WASM as a tool host

**Status:** WASM export implemented; IDE UI is up to the host application (e.g. 8bitworkshop fork).

## Goal

Use the **same** `basic-canvas.wasm` build to run small **utility programs** (image preview, asset validators, etc.) when the user selects a non-code file. The tool is a normal **`.bas`** file; the IDE passes **paths** as **command-line arguments**, exposed in BASIC as **`ARG$(1)`**, **`ARG$(2)`**, … (see below).

## URL vs local paths (LOADSPRITE, OPEN, etc.)

- **`LOADSPRITE`**, **`OPEN`**, and other file paths are resolved against the **Emscripten MEMFS** (and the sprite **base directory** for relative paths), i.e. **local/VFS paths** such as **`/preview.png`** or **`examples/foo.png`**.
- **HTTP/HTTPS URLs are not** passed directly to `fopen` / PNG decode in the sprite path. To load from the network, use **`HTTP$("https://...")`** to fetch bytes, then (today) you would need to **`PRINT#`** to a VFS file or extend the runtime with a dedicated helper — **not** `LOADSPRITE "https://..."` out of the box.

## BASIC API for tool arguments

| Expression | Meaning |
|------------|---------|
| **`ARG$(0)`** | Path of the running **`.bas`** program (same as CLI). |
| **`ARG$(1)`** | First argument **after** the program path. |
| **`ARG$(2)`** | Second trailing argument. |
| **`ARGC()`** | Number of trailing arguments (not including the program path). |

Example tool snippet:

```basic
REM First trailing arg = file to preview (IDE writes to MEMFS first)
F$ = ARG$(1)
IF F$ = "" THEN PRINT "No file": END
LOADSPRITE 1, F$
REM ...
```

## WASM entry point: `basic_load_and_run_gfx_argline`

The canvas build exports **`_basic_load_and_run_gfx_argline`** (see **`Makefile`** `EXPORTED_FUNCTIONS`).

**C signature:**

```c
int basic_load_and_run_gfx_argline(const char *argline);
```

**Behaviour:**

1. Parses **`argline`** into tokens (space-separated; **double- or single-quoted** tokens may contain spaces).
2. **First token** = path to the **`.bas`** file (must exist on **MEMFS**, e.g. **`/ide/png_view.bas`**).
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
// Ensure files exist on Module.FS (writeFile / copy from editor buffer)
const rc = Module.ccall(
  'basic_load_and_run_gfx_argline',
  'number',
  ['string'],
  ['"' + bas + '" "' + png + '"']  // or JSON-escape paths
);
```

Use **`ccall`** / **`cwrap`** with the **mangled** export name **`_basic_load_and_run_gfx_argline`** (Emscripten default).

## IDE workflow (recommended)

1. **Bundle** tool programs under a fixed MEMFS prefix, e.g. **`/ide/tools/png_view.bas`**, at WASM startup (embed in JS or fetch once and `FS.writeFile`).
2. When the user **opens a `.png`** (or other asset):
   - Write bytes to a predictable path, e.g. **`/preview.png`** (or include a hash in the name for parallel tools).
   - Call **`basic_load_and_run_gfx_argline`** with the tool **`.bas`** path and **`/preview.png`** as **`ARG$(1)`**.
3. **Focus** the canvas for **`INKEY$`** / **`GET`** if the tool uses them.
4. On **Stop** / **new file**, stop the run (`wasmStopRequested` / existing canvas controls) before launching another tool.

## Related

- **`docs/tutorial-embedding.md`**, **`web/vfs-helpers.js`** — VFS upload patterns.
- **`web/canvas.html`** — `basic_load_and_run_gfx`, pause/stop hooks.
- **`CHANGELOG.md`** — entry for this export.
