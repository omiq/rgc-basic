# Features to add/to-do

## Phase status: "Bash replacement" + "Full PETSCII" — mostly complete ✓

**Bash replacement:** ARGC/ARG$, stdin/stdout, pipes, SYSTEM, EXEC$ — done.  
**PETSCII experience:** basic-gfx (40×25 window, POKE/PEEK, INKEY$, TI, .seq), {TOKENS}, Unicode→PETSCII, COLORS/BACKGROUND, GET fix, {RESET}/{DEFAULT} — done.

---

* ~INSTR~

* ~**String length limit**~ — Implemented: default 4096; `#OPTION maxstr 255` or `-maxstr 255` for C64 compatibility.

* Flexible DATA read
  * ~RESTORE [line number]~ — implemented; RESTORE resets to first DATA; RESTORE 50 to first DATA at or after line 50.

* ~Decimal ↔ hexadecimal conversion: DEC(),HEX$()~
* ~MOD, <<, >>, AND, OR, XOR (bitwise operators)~

* ~IF THEN ELSE END IF~
  * ~Multi-line IF/ELSE/END IF blocks with nesting; backward compatible with IF X THEN 100~

* ~Structured loops: DO,LOOP,UNTIL,EXIT~
  * ~WHILE … WEND~ implemented.
  * ~DO … LOOP [UNTIL cond]~ and ~EXIT~ implemented. Nested DO/LOOP supported.

* ~Colour without pokes~
  * ~background command for setting screen colour~
  * ~colour/color for text colour~

* ~Cursor On/Off~

* **#OPTION memory addresses** (basic-gfx)
  * Configurable base addresses for screen, colour, charset so POKE/PEEK match different machines.
  * E.g. `#OPTION screen 32768` (PET: $8000) vs default 1024 (C64: $0400). PET programs can be pasted and run with screen address changed.
  * Presets: `#OPTION memory c64` (default) / `#OPTION memory pet`.

* ~**MEMSET, MEMCPY**~ (basic-gfx; see `docs/memory-commands-plan.md`) — **done** (overlap-safe MEMCPY).

* ~**LOAD INTO memory**~ (basic-gfx; see `docs/load-into-memory-plan.md`) — implemented:
  * `LOAD "path" INTO addr [, length]` — load raw binary from file.
  * `LOAD @label INTO addr [, length]` — load from DATA block at label.
  * Terminal build: runtime error "LOAD INTO requires basic-gfx".

* ~**80-column option**~ (terminal, basic-gfx, **WASM canvas**)
  * `#OPTION columns 80` / `-columns 80`; default 40.
  * ~**Terminal**~: `print_width`, wrap, TAB, comma zones; `#OPTION nowrap` / `-nowrap`. Done.
  * ~**basic-gfx**~: 80×25; 640×200 window. Done.
  * ~**basic-wasm-canvas**~: `#OPTION columns 80` selects 640×200 RGBA framebuffer in browser. Done.

* PETSCII symbols & graphics
  * ~Unicode stand-ins~
  * ~Bitmap rendering of 40×25 characters (raylib)~ — **basic-gfx** merged to main.
  * ~Memory-mapped screen/colour/char RAM, POKE/PEEK, PETSCII, `.seq` viewer with SCREENCODES ON~

* **Bitmap graphics & sprites** (incremental; see `docs/bitmap-graphics-plan.md`, `docs/sprite-features-plan.md`)
  1. ~**Bitmap mode**~ — `SCREEN 0`/`SCREEN 1` (320×200 hires at `GFX_BITMAP_BASE`), monochrome raylib renderer; `COLOR`/`BACKGROUND` as pen/paper. ~`PSET`/`PRESET`/`LINE`~; POKE still works.
  2. ~**Sprites (minimal)**~ — `LOADSPRITE` / `UNLOADSPRITE` / `DRAWSPRITE` (persistent pose, z-order, optional `sx,sy,sw,sh` crop) / `SPRITEVISIBLE` / `SPRITEW`/`SPRITEH` / `SPRITECOLLIDE` in basic-gfx + canvas WASM; PNG alpha over text/bitmap; paths relative to `.bas` directory. ~Worked example: `examples/gfx_game_shell.bas` (PETSCII map + PNG player/enemy/HUD), `examples/gfx_sprite_hud_demo.bas`, `examples/player.png`, `examples/enemy.png`, `examples/hud_panel.png`.~ Still open: tilemap `LOADSPRITE` mode.
  3. **Joystick / joypad / controller input** — Poll gamepad via raylib; expose to BASIC as `JOY(port)` or similar read API for D-pad, buttons, axes. Support keyboards-as-joystick and real controllers.
  4. **Graphic layers and scrolling** — Layer stack (background, tiles, sprites, text) with independent scroll offsets; `SCROLL x, y` or per-layer scroll; camera/viewport for games.
  5. **Tilemap handling** — `LOADSPRITE slot, "path", "tilemap"`; define tile size (e.g. 16×16); render tile grid from sprite sheet. Efficient level/world rendering.
  6. **Sprite animation** — Multiple frames per slot; `SPRITEFRAME slot, n` or frame parameter in `DRAWSPRITE`; optional frame rate / timing.

* **Browser / WASM** (see `docs/browser-wasm-plan.md`, `web/README.md`, `README.md`)
  * ~**Emscripten builds**~ — `make basic-wasm` → `web/basic.js` + `basic.wasm`; `make basic-wasm-canvas` → `basic-canvas.js` + `basic-canvas.wasm` (GFX_VIDEO: PETSCII + `SCREEN 1` bitmap + PNG sprites via `gfx_software_sprites.c` / stb_image, parity with basic-gfx). Asyncify for `SLEEP`, `INPUT`, `GET` / `INKEY$`.
  * ~**Demos**~ — `web/index.html` (terminal output div, inline INPUT, `wasm_push_key`); `web/canvas.html` (40×25 / 80×25 PETSCII canvas, shared RGBA buffer + `requestAnimationFrame` refresh during loops/SLEEP).
  * ~**Controls**~ — **Pause** / **Resume** (`Module.wasmPaused`), **Stop** (`Module.wasmStopRequested`); terminal sets `Module.wasmRunDone` when `basic_load_and_run` finishes. Cooperative pause at statement boundaries and yield points (canvas also refreshes while paused).
  * ~**Interpreter fixes for browser**~ — e.g. FOR stack unwind on `RETURN` from `GOSUB` into loops; `EVAL` assignment form; terminal stdout line-buffering for `Module.print`; runtime errors batched for `printErr` on canvas.
  * ~**CI**~ — GitHub Actions WASM job uses **emsdk** (`install latest`), builds both targets, runs Playwright: `tests/wasm_browser_test.py`, `tests/wasm_browser_canvas_test.py`.
  * ~**Deploy hygiene**~ — `canvas.html` pairs cache-bust query on `basic-canvas.js` and `basic-canvas.wasm`; optional `?debug=1` for console diagnostics (`wasm_canvas_build_stamp`, stack dumps).
  * ~**Tutorial embedding**~ — `make basic-wasm-modular`; `web/tutorial-embed.js` + `RgcBasicTutorialEmbed.mount()` for **multiple** terminal instances per page. Guide: **`docs/tutorial-embedding.md`**. Example: `web/tutorial-example.html`. CI: `tests/wasm_tutorial_embed_test.py`, `make wasm-tutorial-test`.
  * **Still open — richer tutorial UX**: step-through debugging or synchronized markdown blocks (beyond Run button + static program text). ~Optional **`runOnEdit`** in `tutorial-embed.js`~ for debounced auto-run after edits.

* ~~Subroutines and Functions~~
  * **User-defined FUNCTIONS** implemented — `FUNCTION name[(params)]` … `RETURN [expr]` … `END FUNCTION`; call with `name()` or `name(a,b)`; recursion supported. See `docs/user-functions-plan.md`.

* Program text preprocessor
  * Replace current ad-hoc whitespace tweaks with a small lexer-like pass for keywords and operators
  * Normalize compact CBM forms while preserving semantics, e.g.:
    * `IFX<0THEN` → `IF X<0 THEN`
    * `FORI=1TO9` → `FOR I=1 TO 9`
    * `GOTO410` / `GOSUB5400` → `GOTO 410` / `GOSUB 5400`
    * `IF Q1<1ORQ1>8ORQ2<1ORQ2>8 THEN` → proper spacing around `OR` and `AND`
  * Ensure keywords are only recognized when not inside identifiers (e.g. avoid splitting `ORD(7)` or `FOR`), and never mangling string literals
  * Validate behavior against reference interpreter (`cbmbasic`) with a regression suite of tricky lines

* ~Include files / libraries~
  * ~#INCLUDE "path" implemented; relative to current file; duplicate line/label errors; circular include detection~
* ~Shebang-aware loader~
  * ~First line `#!...` ignored; #OPTION mirrors CLI (file overrides)~

* ~Reserved-word / identifier hygiene (variables)~
  * ~Reserved words cannot be used as variables; error "Reserved word cannot be used as variable"~
  * Labels may match keywords (e.g. `CLR:` in trek.bas); context distinguishes.
  * ~Underscores in identifiers~ — `is_prime`, `my_var` etc. now allowed.
  * Improve error messages where possible

* ~**String & array utilities**~ (see `docs/string-array-utils-plan.md`) — SPLIT, REPLACE, INSTR start, INDEXOF, SORT, TRIM$, JOIN, FIELD$, ENV$, JSON$, EVAL — all done. Key-value emulation via SPLIT+FIELD$; no dedicated DICT type for now.
  * ~**SPLIT**~ — `arr$ = SPLIT(csv$, ",")` — split string by delimiter into array.
  * ~**REPLACE**~ — `result$ = REPLACE(original$, "yes", "no")`.
  * ~**INSTR start**~ — `INSTR(str$, find$, start)` — optional start position for find-next loops.
  * ~**INDEXOF / LASTINDEXOF**~ — `INDEXOF(arr, value)` — 1-based index in array, 0 if not found.
  * ~**SORT**~ — `SORT arr [, mode]` — in-place sort; asc/desc, alpha/numeric.
  * ~**TRIM$**~ — strip leading/trailing whitespace (CSV, input).
  * ~**JOIN**~ — inverse of SPLIT: `JOIN(arr$, ",")`.
  * ~**FIELD$**~ — `FIELD$(str$, delim$, n)` — get Nth field (awk-like).
  * ~**ENV$**~ — `ENV$(name$)` — environment variable.
  * ~**PLATFORM$**~ — `PLATFORM$()` — returns `"linux-terminal"`, `"linux-gfx"`, `"windows-terminal"`, `"windows-gfx"`, `"mac-terminal"`, `"mac-gfx"`. Enables conditional code for paths/behavior.
  * ~**JSON$**~ — `JSON$(json$, path$)` — path-based extraction from JSON string (no new types); e.g. `JSON$(j$, "users[0].name")`.
  * ~**EVAL**~ — `EVAL(expr$)` — evaluate string as BASIC expression at runtime; useful for interactive testing.

* **Optional debug logging**
  * **Load logging** (`-debug load`): at each stage of `load_file_into_program` — raw line, after trim, directive handling (#OPTION/#INCLUDE), line number, after transform, after normalize. Helps debug parsing, include order, keyword expansion.
  * **Execution logging** (`-debug exec`): at each statement — line number, statement text, control flow (GOTO/GOSUB/RETURN), optionally expression results and variable writes. High volume; useful for stepping through tricky logic.

* **Future: IL/compilation**
  * Shelved for now: optional caching of processed program. Revisit when moving beyond pure interpretation to some form of IL or bytecode compilation — cache would then be meaningful (skip parse at load and potentially at exec).

---

## Potential priorities & sequence (post bash/PETSCII)

| Order | Item | Rationale |
|-------|------|------------|
| ~**1**~ | ~String length limit~ | Done. |
| ~**2**~ | ~String utils batch 1: INSTR start, REPLACE, TRIM$~ | Done. |
| ~**3**~ | ~RESTORE [line]~ | Done. |
| ~**4**~ | ~LOAD INTO memory~ | Done. |
| ~**5**~ | ~String utils batch 2: SORT, SPLIT, JOIN, FIELD$~ | Done. |
| ~**6**~ | ~INDEXOF, LASTINDEXOF~ | Done. |
| ~**7**~ | ~MEMSET, MEMCPY~ | Done. |
| ~**8**~ | ~ENV$, PLATFORM$, JSON$, EVAL~ | Done. |
| ~**9**~ | ~80-column option (terminal + basic-gfx + WASM canvas)~ | Done. |
| ~**10**~ | ~Browser/WASM (terminal + canvas demos, CI, pause/stop)~ | **Done** (see bullet list above). |
| **11** | Bitmap/sprites (remaining) | `SPRITECOLLIDE`, tilemap `LOADSPRITE`; joystick, layers, animation — see sprite plan. |
| **Later** | Optional debug logging (load + exec) | `-debug load`, `-debug exec`; verbose but useful for diagnostics. |
| **Later** | Program preprocessor, #OPTION memory | Polish; niche. |
| **Later** | WASM tutorial UX extras | Auto-run, stepping, deep IDE integration (embed API exists). |

---

**Completed (removed from list):**

* **Shell scripting update** — Full support for using the interpreter as a script runner: **command-line arguments** (`ARGC()`, `ARG$(0)`…`ARG$(n)`), **standard I/O** (INPUT from stdin, PRINT to stdout, errors to stderr; pipes and redirection work), and **system commands** (`SYSTEM("ls -l")` for exit code, `EXEC$("whoami")` to capture output). Example: `examples/scripting.bas`. See README “Shell scripting: standard I/O and arguments”.

- **Command-line arguments** — `ARGC()` and `ARG$(n)` (ARG$(0)=script path, ARG$(1)…=args). Run: `./basic script.bas arg1 arg2`.
- **Standard in/out** — `INPUT` reads stdin, `PRINT` writes stdout; errors/usage to stderr. Pipes work (e.g. `echo 42 | ./basic prog.bas`).
- **Execute system commands** — `SYSTEM("cmd")` runs a command and returns exit code; `EXEC$("cmd")` runs and returns stdout as a string (see README and `examples/scripting.bas`).
- Multi-dimensional arrays — `DIM A(x,y)` (and up to 3 dimensions) in `basic.c`.
- **CLR statement** — Resets all variables (scalar and array elements) to 0/empty, clears GOSUB and FOR stacks, resets DATA pointer; DEF FN definitions are kept.
- **String case utilities** — `UCASE$(s)` and `LCASE$(s)` implemented (ASCII `toupper`/`tolower`); use in expressions and PRINT.
- **File I/O** — `OPEN lfn, device, secondary, "filename"` (device 1: file; secondary 0=read, 1=write, 2=append), `PRINT# lfn, ...`, `INPUT# lfn, var,...`, `GET# lfn, stringvar`, `CLOSE [lfn]`. `ST` (status) set after INPUT#/GET# (0=ok, 64=EOF, 1=error). Tests: `tests/fileio.bas`, `tests/fileeof.bas`, `tests/test_get_hash.bas`.
- **RESTORE** — resets DATA pointer so next READ uses the first DATA value again (C64-style).

- **INSTR** — `INSTR(source$, search$)` returns the 1-based position of `search$` in `source$`, or 0 if not found.

- **Decimal ↔ hexadecimal conversion** — `DEC(s$)` parses a hexadecimal string to a numeric value (invalid strings yield 0); `HEX$(n)` formats a number as an uppercase hexadecimal string.

- **Colour without pokes** — `COLOR n` / `COLOUR n` set the foreground colour using a C64-style palette index (0–15), and `BACKGROUND n` sets the background colour, all mapped to ANSI SGR.

- **Cursor On/Off** — `CURSOR ON` / `CURSOR OFF` show or hide the blinking cursor using ANSI escape codes; tested with simple smoke programs.

- **basic-gfx (raylib PETSCII graphics)** — Windowed 40×25 PETSCII text screen, POKE/PEEK screen/colour/char RAM, INKEY$, TI/TI$, SCREENCODES ON (PETSCII→screen conversion for .seq viewers), `.seq` colaburger viewer with correct rendering, window closes on END.

- **Variable names** — Full names (up to 31 chars) significant; SALE and SAFE distinct. Reserved words rejected for variables/labels.

- **IF ELSE END IF** — Multi-line `IF cond THEN` … `ELSE` … `END IF` blocks; nested blocks supported.
- **WHILE WEND** — Pre-test loop `WHILE cond` … `WEND`; nested loops supported.
- **DO LOOP UNTIL EXIT** — `DO` … `LOOP [UNTIL cond]`; `EXIT` leaves the innermost DO; nested loops supported.
- **Meta directives** — Shebang, #OPTION (petscii, charset, palette), #INCLUDE; duplicate line/label errors; circular include detection. See `docs/meta-directives-plan.md`.

- **Browser / WASM** — `make basic-wasm` / `make basic-wasm-canvas`; `web/index.html` and `web/canvas.html`; Asyncify; virtual FS; Playwright smoke tests; CI via emsdk; Pause/Resume/Stop; paired JS+WASM cache-bust on canvas page. See `README.md`, `web/README.md`, `AGENTS.md`.

