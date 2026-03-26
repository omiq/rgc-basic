## Changelog

### Unreleased

- **Loader**: Lines like **`10 #OPTION charset lower`** in a **numberless** program (first line starts with a digit) are accepted — strip the numeric prefix so **`#OPTION` / `#INCLUDE`** apply (fixes canvas paste style where charset never switched).
- **Charset lower + CHR$**: With lowercase char ROM, non-letter bytes from **`CHR$(n)`** (and punctuation) use **raw screen code** `sc = byte`; **`petscii_to_screencode(65)`** was mapping to lowercase glyphs. **Regression**: `tests/wasm_canvas_charset_test.py`, **`make wasm-canvas-charset-test`** (includes numbered-`#OPTION` paste); CI workflow **`wasm-tests.yml`** runs full WASM Playwright suite on **push/PR to `main`**; release WASM job runs charset test too.

- **Browser canvas**: `#OPTION charset lower` (and charset from CLI before run) now applies when video state attaches — fixes PETSCII space (screen code 32) drawing as wrong glyph (e.g. `!`) because the uppercase char ROM was still active.
- **INPUT (canvas / GFX)**: When **Stop** / watchdog sets `wasmStopRequested` while waiting in `gfx_read_line`, report **"Stopped"** instead of **"Unexpected end of input"** (misleading; not EOF).

- **PETSCII + lowercase charset**: With lowercase video charset, **ASCII letters** in string literals use `gfx_ascii_to_screencode_lowcharset()`; **all other bytes** (including **`CHR$(n)`** and punctuation) use **`petscii_to_screencode()`** so `CHR$(32)` is space and `CHR$(65)` matches PETSCII semantics (was wrongly treated as ASCII, shifting output). Works with or without **`-petscii`** on the host. `wasm_browser_canvas_test` covers charset lower with and without the PETSCII checkbox.

- **Project**: Renamed to **RGC-BASIC** (Retro Game Coders BASIC). GitHub: **`omiq/rgc-basic`**. Tagline: modern cross-platform BASIC interpreter with classic syntax compatibility, written in C. WASM CI artifact: **`rgc-basic-wasm.tar.gz`**. Tutorial CSS classes: `rgc-tutorial-*` (`cbm-tutorial-*` removed). JS: prefer **`RgcBasicTutorialEmbed`** / **`RgcVfsHelpers`** (deprecated **`Cbm*`** aliases retained briefly).

- **Browser / WASM (Emscripten)**
  - **Builds**: `make basic-wasm` → `web/basic.js` + `basic.wasm`; `make basic-wasm-canvas` → `basic-canvas.js` + `basic-canvas.wasm` (PETSCII + bitmap + PNG sprites via `gfx_canvas.c` / `gfx_software_sprites.c`, `GFX_VIDEO`). Asyncify for cooperative `SLEEP`, `INPUT`, `GET` / `INKEY$`.
  - **Demos**: `web/index.html` — terminal-style output, inline INPUT, `wasm_push_key` for GET/INKEY$; `web/canvas.html` — 40×25 or 80×25 canvas, shared RGBA framebuffer refreshed during loops and SLEEP.
  - **Controls**: Pause / Resume (`Module.wasmPaused`), Stop (`Module.wasmStopRequested`); terminal run sets `Module.wasmRunDone` when `basic_load_and_run` completes. FOR stack unwinds on `RETURN` from subroutines using inner `FOR` loops (e.g. GOSUB loaders).
  - **Interpreter / glue**: Terminal WASM stdout line-buffering for correct `PRINT` newlines in HTML; canvas runtime errors batched for `printErr`; `EVAL` supports `VAR = expr` assignment form in evaluated string. `canvas.html` uses matching `?cb=` on JS and WASM to avoid `ASM_CONSTS` mismatch from partial cache.
  - **CI**: GitHub Actions WASM job installs **emsdk** (`latest`) instead of distro `apt` emscripten; builds both targets; runs `tests/wasm_browser_test.py` and `tests/wasm_browser_canvas_test.py`.
  - **Optional**: `canvas.html?debug=1` — console diagnostics (`wasm_canvas_build_stamp`, stack dumps on error).
  - **Tutorial embedding**: `make basic-wasm-modular` → `web/basic-modular.js` + `basic-modular.wasm` (`MODULARIZE=1`, `createBasicModular`). `web/tutorial-embed.js` mounts multiple terminal-style interpreters per page (`RgcBasicTutorialEmbed.mount`; `CbmBasicTutorialEmbed` deprecated alias). Guide: `docs/tutorial-embedding.md`; example: `web/tutorial-example.html`. Test: `make wasm-tutorial-test`.
  - **Virtual FS upload/export**: `web/vfs-helpers.js` — `RgcVfsHelpers` (`CbmVfsHelpers` deprecated alias): `vfsUploadFiles`, `vfsExportFile`, `vfsMountUI` (browser → MEMFS and MEMFS → download). Wired into `web/index.html`, `web/canvas.html`, and tutorial embeds (`showVfsTools`). CI WASM artifacts include `vfs-helpers.js`.
  - **Canvas GFX parity with basic-gfx**: `SCREEN 1` bitmap rendering; software PNG sprites (`gfx/gfx_software_sprites.c`, vendored `gfx/stb_image.h`) replacing the old WASM sprite stubs; compositing order matches Raylib (base then z-sorted sprites). `web/canvas.html` draws `#OPTION border` padding from `Module.wasmGfxBorderPx` / `wasmGfxBorderColorIdx`. Guide: `docs/gfx-canvas-parity.md`. `tests/wasm_browser_canvas_test.py` covers bitmap + sprite smoke.
  - **Example**: `examples/gfx_canvas_demo.bas` + `gfx_canvas_demo.png` (and `web/gfx_canvas_demo.png` for Playwright fetch); canvas test runs the full demo source.
  - **Docs**: `docs/ide-retrogamecoders-canvas-integration.md` — embed canvas WASM in an online IDE (MEMFS, play/pause/stop, iframe flow); linked from `web/README.md`.

- **80-column option (terminal + basic-gfx + WASM canvas)**
  - **Terminal**: `#OPTION columns N` / `-columns N` (1–255); default 40. Comma/TAB zones scale: 10 at 40 cols, 20 at 80 cols. `#OPTION nowrap` / `-nowrap`: disable wrapping.
  - **basic-gfx**: `-columns 80` for 80×25 screen; 2000-byte buffer; window 640×200. `#OPTION columns 80` in program also supported.
  - **WASM canvas**: `#OPTION columns 80` selects 640×200 framebuffer in browser (`basic-wasm-canvas`).
- **basic-gfx — hires bitmap (Phase 3)**
  - `SCREEN 0` / `SCREEN 1` (text vs 320×200 monochrome); `PSET` / `PRESET` / `LINE x1,y1 TO x2,y2`; bitmap RAM at `GFX_BITMAP_BASE` (0x2000).
- **basic-gfx — PNG sprites**
  - `LOADSPRITE`, `UNLOADSPRITE`, `DRAWSPRITE` (persistent per-slot pose, z-order, optional source rect), `SPRITEVISIBLE`, `SPRITEW()` / `SPRITEH()`; alpha blending over PETSCII/bitmap; `gfx_set_sprite_base_dir` from program path.
  - Examples: `examples/gfx_sprite_hud_demo.bas`, `examples/gfx_game_shell.bas` (+ `player.png`, `enemy.png`, `hud_panel.png`).

### 1.5.0 – 2026-03-20

- **String length limit**
  - `#OPTION maxstr N` / `-maxstr N` (1–4096); default 4096. Use `maxstr 255` for C64 compatibility.
- **String utilities**
  - `INSTR(source$, search$ [, start])` — optional 1-based start position.
  - `REPLACE(str$, find$, repl$)` — replace all occurrences.
  - `TRIM$(s$)`, `LTRIM$(s$)`, `RTRIM$(s$)` — strip whitespace.
  - `FIELD$(str$, delim$, n)` — extract Nth field from delimited string.
- **Array utilities**
  - `SORT arr [, mode]` — in-place sort (asc/desc, alpha/numeric).
  - `SPLIT str$, delim$ INTO arr$` / `JOIN arr$, delim$ INTO result$ [, count]`.
  - `INDEXOF(arr, value)` / `LASTINDEXOF(arr, value)` — 1-based index, 0 if not found.
- **RESTORE [line]** — reset DATA pointer to first DATA at or after the given line.
- **LOAD INTO** (basic-gfx) — `LOAD "path" INTO addr` or `LOAD @label INTO addr`; load raw bytes from file or DATA block.
- **MEMSET / MEMCPY** (basic-gfx) — fill or copy bytes in virtual memory.
- **ENV$(name$)** — environment variable lookup.
- **PLATFORM$()** — returns `"linux-terminal"`, `"windows-gfx"`, `"mac-terminal"`, etc.
- **JSON$(json$, path$)** — path-based extraction from JSON (e.g. `"users[0].name"`).
- **EVAL(expr$)** — evaluate a string as a BASIC expression at runtime.
- **DO … LOOP [UNTIL cond]** and **EXIT**
  - `DO` … `LOOP` — infinite loop (until `EXIT`).
  - `DO` … `LOOP UNTIL cond` — post-test loop.
  - `EXIT` — leaves the innermost DO loop. Nested DO/LOOP supported.
- **CI**
  - Skip pty GET test when `script -c` unavailable (macOS BSD).
  - Skip GET tests on Windows (console input only; piped stdin would hang).

### 1.4.0 – 2026-03-18

- **User-defined FUNCTIONS** (implemented)
  - Multi-line, multi-parameter: `FUNCTION name [(params)]` … `RETURN [expr]` … `END FUNCTION`.
  - Call from expressions: `x = add(3, 5)`; as statement for side effects: `sayhi()`.
  - Brackets always required; optional params; `RETURN` with no expr or `END FUNCTION` yields 0/`""`.
  - Coexists with `DEF FN` (different arity). See `docs/user-functions-plan.md`.
- **Graphical interpreter (basic-gfx)** — full raylib-based 40×25 PETSCII window
  - Complete graphical version of the interpreter: `basic-gfx` alongside terminal `basic`.
  - `POKE`/`PEEK` screen/colour/char RAM, `INKEY$`, `TI`/`TI$`, `.seq` art viewers.
  - PETSCII→screen code conversion when `SCREENCODES ON`; reverse-video fixed.
  - Window closes on `END`. Build with `make basic-gfx` (requires Raylib).
- **Meta directives** (`#` prefix, load-time)
  - Shebang: `#!/usr/bin/env basic` on first line ignored.
  - `#OPTION petscii|petscii-plain|charset upper|lower|palette ansi|c64` — file overrides CLI.
  - `#INCLUDE "path"` — splice file at that point; relative to current file; duplicate line numbers and labels error.
- **WHILE … WEND**
  - Pre-test loop: `WHILE cond` … `WEND`. Nested WHILE/WEND supported.
- **IF ELSE END IF**
  - Multi-line blocks: `IF cond THEN` … `ELSE` … `END IF`. Nested blocks supported.
  - Backward compatible: `IF X THEN 100` and `IF X THEN PRINT "Y"` unchanged.
- **Variable naming**
  - Full variable names (up to 31 chars) are now significant; `SALE` and `SAFE` are distinct.
  - Underscores (`_`) allowed in identifiers (e.g. `is_prime`, `my_var`).
  - Reserved-word check: keywords cannot be used as variables; clear error on misuse. Labels may match keywords (e.g. `CLR:`).
- **basic-gfx PETSCII / .seq viewer**
  - PETSCII→screen code conversion when `SCREENCODES ON`; `.seq` streams display correctly.
  - Reverse-video rendering fixed (W, P, etc. in “Welcome”, “Press”) via renderer fg/bg swap.
  - Window closes automatically when program reaches `END`.
  - `examples/gfx_colaburger_viewer.bas` with `-petscii -charset lower`.
- **GFX charset toggle**
  - `CHR$(14)` switches to lowercase, `CHR$(142)` switches back.
  - `-charset lower|upper` sets initial charset in `basic-gfx`.
- **Documentation**
  - Sprite features planning doc (`docs/sprite-features-plan.md`).
  - Meta directives plan (`docs/meta-directives-plan.md`) — shebang, #OPTION, #INCLUDE.
  - User-defined functions plan (`docs/user-functions-plan.md`).
  - Tutorial examples: `examples/tutorial_functions.bas`, `examples/tutorial_lib.bas`, `examples/tutorial_menu.bas` — FUNCTIONS, #INCLUDE, WHILE, IF ELSE END IF.
  - README, to-do, and `docs/bitmap-graphics-plan.md` updated for merged GFX.
  - Removed colaburger test PNG/MD artifacts.

### 1.0.0 – 2026-03-09

Baseline “version 1” tag capturing the current feature set.

- **Core interpreter**
  - CBM BASIC v2–style: `PRINT`, `INPUT`, `IF/THEN`, `FOR/NEXT`, `GOTO`, `GOSUB`, `DIM`, `DEF FN`, `READ`/`DATA` + `RESTORE`, `CLR`, multi-dimensional arrays, string functions (`MID$`, `LEFT$`, `RIGHT$`, `INSTR`, `UCASE$`, `LCASE$`), and numeric functions (`SIN`, `COS`, `TAN`, `RND`, etc.).
  - File I/O (`OPEN`, `PRINT#`, `INPUT#`, `GET#`, `CLOSE`, `ST`) and the built‑in examples (`trek.bas`, `adventure.bas`, `fileio_basics.bas`, etc.).
- **PETSCII and screen control**
  - `-petscii` and `-petscii-plain` modes with a faithful PETSCII→Unicode table (C64 graphics, card suits, £, ↑, ←, block elements) and ANSI control mapping (`CHR$(147)` clear screen, cursor movement, colours, reverse video).
  - PETSCII token expansion inside strings via `{TOKENS}` (colour names, control keys, numeric codes).
  - Column‑accurate PETSCII `.seq` viewer (`examples/colaburger_viewer.bas`) with proper wrapping at 40 visible columns and DEL (`CHR$(20)`) treated as a real backspace (cursor left + delete char).
- **Terminal/UI helpers**
  - `SLEEP` (60 Hz ticks), `LOCATE`, `TEXTAT`, `CURSOR ON/OFF`, `COLOR` / `COLOUR`, and `BACKGROUND` with a C64‑style palette mapped to ANSI.
- **Shell scripting support**
  - Command‑line arguments via `ARGC()` and `ARG$(n)` (`ARG$(0)` = script path; `ARG$(1)…ARG$(ARGC())` = arguments).
  - Standard I/O suitable for pipes and redirection: `INPUT` from stdin, `PRINT` to stdout, diagnostics to stderr.
  - Shell integration: `SYSTEM(cmd$)` runs a command and returns its exit status; `EXEC$(cmd$)` runs a command and returns its stdout as a string (trailing newline trimmed).
  - Example `examples/scripting.bas` showing argument handling and simple shell‑style tasks.

Future changes should be added above this entry with a new version and date.

