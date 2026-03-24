# Browser / WASM Target Plan

Goal: Run the CBM-BASIC interpreter in the browser, performant enough for user-supplied programs and assets (data, graphics, game levels), with support for tutorial embedding and integration into an online retro IDE.

---

## Options Overview

| Approach | Effort | Pros | Cons |
|----------|--------|------|-----|
| **A. Emscripten + stdio shims** | Low–med | Minimal code change; virtual FS for files | SYSTEM/EXEC$ no-op; GET/INPUT need UI hooks |
| **B. Pluggable I/O layer** | Med | Clean abstraction; easy to add canvas/gfx later | Refactor fopen, PRINT, INPUT, file I/O |
| **C. Separate JS interpreter** | High | No C/WASM; full control | Rewrite; divergence from main interpreter |

**Recommended: A** for fastest path; consider B if we hit limits.

---

## 1. Emscripten Compilation

Compile `basic.c` + `petscii.c` to WASM. No GFX (raylib) initially.

**Build:**
```
emcc -O2 -s WASM=1 -s EXPORTED_FUNCTIONS='["_run_basic","_load_program",...]' \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \
  basic.c petscii.c -lm -o basic.js
```

**Conditional compilation:** `#ifdef __EMSCRIPTEN__` for:
- Stub or omit: `SYSTEM()`, `EXEC$()` (return error or JS callback)
- Stub or simplify: `tcgetattr` / `termios` (GET uses prompt or callback)
- Omit: raylib, pthread (GFX build not used)

---

## 2. Program and Asset Loading

**User-supplied programs:**
- **String API:** `run_basic(program_string)` — program passed as C string; no files.
- **Virtual FS:** Emscripten `FS.writeFile("program.bas", contents)` before run; interpreter uses `fopen("program.bas","r")` as today.
- **Preload at build:** `--preload-file program.bas` for bundled examples.

**User-supplied assets (DATA, levels, graphics):**
- Same virtual FS: user uploads or IDE provides files; we `FS.writeFile("level.dat", data)`.
- `OPEN 1,1,0,"level.dat"` and `LOAD "sprites.bin" INTO addr` (future) read from virtual FS.
- **Tutorial embedding:** Embed program + assets as base64/data URLs; write to virtual FS on init.

**Flow for IDE:**
1. User edits program in editor.
2. User optionally adds assets (file picker → ArrayBuffer).
3. On Run: `FS.writeFile("program.bas", editorContent)`; optionally `FS.writeFile("level.dat", assetData)`.
4. Call `ccall("run_basic", null, ["string"], ["program.bas"])` or equivalent.

---

## 3. I/O Modes for Browser

| Mode | PRINT | INPUT | GET | File I/O |
|------|-------|-------|-----|----------|
| **Terminal div** | Append to DOM/textarea | `prompt()` or input field | Key handler on document/div | Virtual FS |
| **Canvas** | Draw to 40×25 char grid (PETSCII) | Overlay input field | Key handler | Virtual FS |
| **Compute-only** | Buffer or discard | Stub / buffer | Stub | Virtual FS |
| **Embedded (tutorial)** | Append to designated div | Modal or inline input | Optional | Virtual FS or inline DATA |

**Recommended first:** Terminal div. Add canvas later (similar to basic-gfx but with Canvas 2D/WebGL).

---

## 4. Public API (JS)

```javascript
// Load and run a program (uses virtual FS path)
Basic.run("program.bas");

// Run from string (no files; DATA from inline string)
Basic.runString(`
  10 DATA 1,2,3
  20 READ A,B,C
  30 PRINT A+B+C
  40 END
`);

// With assets
Basic.writeFile("level.txt", "1,2,3,4,5");
Basic.run("program.bas");

// Callbacks for embedding
Basic.onPrint = (text) => { outputDiv.textContent += text; };
Basic.onInput = (prompt) => { return window.prompt(prompt) || ""; };
Basic.onError = (msg) => { console.error(msg); };
```

---

## 5. Performance

- **Interpreter:** Pure C, no JIT. WASM is typically 1–2× native; fine for typical BASIC.
- **Yielding:** Long runs can block the main thread. Option: run N statements, then `emscripten_set_main_loop` or `requestAnimationFrame` to yield. Trade-off: complexity vs responsiveness.
- **Assets:** Virtual FS is in-memory; no network delay once loaded.
- **Initial target:** Programs like `trek.bas`, `adventure.bas`, tutorial examples — all well within WASM performance.

---

## 6. Tutorial Embedding

```html
<basic-runner program="10 PRINT &quot;HELLO&quot;&#10;20 END" output="out"></basic-runner>
<div id="out"></div>
```

Or:

```html
<script src="basic.js"></script>
<script>
  Basic.runString("10 PRINT \"HELLO\"\n20 END", { outputId: "out" });
</script>
```

Examples: Run button, optional Step, output div, optional canvas for PETSCII.

---

## 7. Retro IDE Integration

- Same WASM module as above.
- Editor (CodeMirror, Monaco, or simple `<textarea>`) for program.
- File sidebar: virtual files (program + assets). User adds files via upload.
- Run: write to virtual FS, then `Basic.run("program.bas")`.
- Output: terminal div or canvas. Option for PETSCII/40-col display.
- Sharing: export as single HTML + embedded program/assets, or URL with base64 program.

---

## 8. Implementation Phases

| Phase | Scope | Deliverable |
|-------|-------|-------------|
| **1. Minimal WASM** | basic.c + petscii.c, no GFX; stub SYSTEM/EXEC; stdio → JS console or buffer | `basic.js` + `basic.wasm`; `basic_load_and_run(path)` via virtual FS |
| **2. Virtual FS + run file** | Emscripten FS; `Basic.writeFile`; `Basic.run(path)` | Load program and assets from virtual FS |
| **3. Terminal div mode** | PRINT → div; INPUT → prompt or callback | Embeddable terminal UI |
| **4. Canvas mode (optional)** | 40×25 PETSCII grid, Canvas 2D; no raylib | In-browser PETSCII display |
| **5. Async/yield (optional)** | Cooperate with event loop for long runs | Responsive UI during heavy loops |

---

## 9. Dependencies to Abstract (for Emscripten)

| Current | WASM approach |
|---------|---------------|
| `fopen`/`fgets` (program load) | Emscripten FS or `runString` path |
| `fopen` (OPEN 1,1,0,"x") | Emscripten FS |
| `printf`/`fputc` (PRINT) | `#ifdef __EMSCRIPTEN__` → JS callback or buffer |
| `fgets(stdin)` (INPUT) | JS callback (prompt / custom UI) |
| `getchar` / termios (GET) | JS key handler or callback |
| `SYSTEM`/`EXEC$` | Stub: runtime error or optional JS callback |
| `time` / `SLEEP` | `emscripten_get_now()`; `emscripten_sleep()` for SLEEP |
| GFX (raylib) | Omit; use Canvas for any graphical output |

---

## 10. File Structure (Proposed)

```
Makefile          # Add target: make basic-wasm
basic.c           # #ifdef __EMSCRIPTEN__ for I/O shims
petscii.c         # No changes expected
web/
  index.html      # Demo runner
  basic.js        # Emscripten output
  basic.wasm      # Emscripten output
  basic-api.js    # Wrapper: Basic.runString, Basic.writeFile, etc.
```

---

## Summary

**Fast path:** Emscripten, virtual FS, `runString` + `run(path)`, terminal div I/O. Stub SYSTEM/EXEC; GET/INPUT via callbacks. Suitable for tutorials and IDE.

**Later:** Canvas PETSCII mode, async yields, richer asset handling (e.g. LOAD into memory for sprites).
