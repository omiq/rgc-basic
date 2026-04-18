# Features to add/to-do

## Naming convention for new commands

**Two-word verb/noun style for new graphics commands** (AMOS/STOS precedent):

- `SPRITE LOAD`, `SPRITE DRAW`, `SPRITE FRAME`, `SPRITE FREE`, `SPRITE FRAMES(...)`
- `TILE DRAW`, `TILE COUNT(...)`
- `TILEMAP DRAW`
- `SHEET COLS(...)`, `SHEET ROWS(...)`, `SHEET WIDTH(...)`, `SHEET HEIGHT(...)`
- `IMAGE NEW`, `IMAGE FREE`, `IMAGE COPY` (shipped); `IMAGE SAVE`,
  `IMAGE GRAB` (planned, Phase 2/3 of blitter spec)

Dropped from the original proposal:
- ~~`SCREEN OFFSET`, `SCREEN ZONE`, `SCREEN SCROLL`~~ — `IMAGE COPY`
  already covers scrolling and parallax; see
  `docs/tilemap-sheet-plan.md` "Scrolling — covered by IMAGE COPY".

**Existing concat names stay as permanent aliases** — not deprecated,
no warnings, no removal date:

| New (canonical) | Concat alias (permanent) |
|---|---|
| `SPRITE LOAD` | `LOADSPRITE` |
| `SPRITE DRAW` | `DRAWSPRITE` |
| `SPRITE FRAME` | `SPRITEFRAME` |
| `SPRITE FREE` | `FREESPRITE` |
| `TILE DRAW` | `DRAWTILE` / `DRAWSPRITETILE` |
| `TILE COUNT(...)` | `SPRITETILES(...)` |
| `TILEMAP DRAW` | `DRAWTILEMAP` |

Both spellings tokenise to the same opcode. Pick per taste; docs lead
with two-word form for new material. Applies to **new** commands only;
don't retroactively rewrite working code.

Rationale: two-word grammar groups features visually (`SPRITE *`,
`TILE *`, `SHEET *`, `IMAGE *`, `SCROLL *`), reads closer to English,
matches AMOS/STOS precedent. Concat aliases preserve backward
compatibility for every tutorial, WordPress embed, and shared program.

---

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

* ~**#OPTION memory addresses** (basic-gfx / canvas WASM)~ — Implemented:
  * `#OPTION memory c64` / `pet` / `default`; per-region `#OPTION screen` / `colorram` / `charmem` / `keymatrix` / `bitmap` with decimal or `$hex` / `0xhex`.
  * CLI: `-memory c64|pet|default` (basic-gfx). Overlapping 16-bit addresses use fixed priority: text → colour → charset → keyboard → bitmap.

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

* **Configurable text row count (`#OPTION rows N` / `OPTION ROWS N`)** — *idea; not started.*  
  Today **basic-gfx** and **canvas WASM** use a fixed **25** text rows (`GFX_ROWS` / `SCREEN_ROWS`); screen/colour buffers are **2000** bytes (`GFX_TEXT_SIZE`), i.e. **40×25** or **80×25** layout.
  - **Easier subset:** **40 columns × 50 rows = 2000** cells — same total size as **80×25**, so the existing buffer could suffice **if** wide mode is constrained (e.g. cap rows when `columns=80`, or only allow 50 rows in 40-column mode until buffers grow).
  - **Harder:** **80×50** needs **4000** bytes (or dynamic allocation) and touches `GfxVideoState`, `gfx_peek`/`gfx_poke`, and anything assuming **2000** bytes.
  - **Front-ends:** window / framebuffer height becomes **rows×8** (50 rows → **400** px tall vs today’s **200**); WASM RGBA size and any hard-coded **200** in `canvas.html` / JS must track **rows**.
  - **Difficulty:** **moderate** — dozens of touch points across the interpreter and both renderers, but **bounded**; implementing **40×50** first is **materially simpler** than fully general **rows × columns** with a larger RAM model.

* **VGA-style 640×480 addressable pixels** — *idea; not started.* Goal: a **screen** / mode where the composited output is a **true 640×480** pixel surface (late-80s / early-90s **IBM PC VGA** feel), not merely **upscaling** the current **640×200** (80×25×8) framebuffer in the window.
  - **Distinct from:** “640×480 window” that **stretches or letterboxes** existing **640×200** content — that would be **low–moderate** effort (presentation only).
  - **This idea:** **every pixel** in **640×480** is a first-class drawing target — implies rethinking **text grid** (e.g. **80×60** at **8×8** cells, or non-8×8 metrics), **hires bitmap** (today **`GFX_BITMAP_*`** is **320×200** 1bpp), **sprites** (positioning, clipping, z-order), **`SCROLL`**, borders, and **WASM RGBA** buffer size (**640×480×4 ≈ 1.2 MiB** per full frame vs today’s **640×200×4**).
  - **Overlaps:** configurable **`rows`** / larger **`GFX_TEXT_SIZE`**, possible **separate “VGA mode”** vs **C64-compat** mode so existing programs stay predictable.
  - **Difficulty:** **high** — cross-cutting; comparable to a **new display preset** plus buffer growth and renderer work in **basic-gfx**, **canvas WASM**, and any **POKE/PEEK** semantics if video memory is exposed.

* **Sample sound playback (basic-gfx + canvas WASM only)** — *idea; not started.* Design: **`docs/rgc-sound-sample-spec.md`**. MVP: **single voice** (new **`PLAYSOUND`** stops previous), **`LOADSOUND` / `UNLOADSOUND` / `PLAYSOUND` / `STOPSOUND` / `PAUSESOUND` / `RESUMESOUND` / `SOUNDVOL`**, **`SOUNDPLAYING()`**; **non-blocking** gameplay; **WAV (PCM)** first; native **Raylib** with **command queue** from interpreter thread to main loop; **Web Audio** on WASM + **VFS** paths. **Difficulty:** **moderate** (native) to **moderate–high** (+ WASM); terminal build out of scope.

* PETSCII symbols & graphics
  * ~Unicode stand-ins~
  * ~Bitmap rendering of 40×25 characters (raylib)~ — **basic-gfx** merged to main.
  * ~Memory-mapped screen/colour/char RAM, POKE/PEEK, PETSCII, `.seq` viewer with SCREENCODES ON~

* **Bitmap graphics & sprites** (incremental; see `docs/bitmap-graphics-plan.md`, `docs/sprite-features-plan.md`)
  1. ~**Bitmap mode**~ — `SCREEN 0`/`SCREEN 1` (320×200 hires at `GFX_BITMAP_BASE`), monochrome raylib renderer; `COLOR`/`BACKGROUND` as pen/paper. ~`PSET`/`PRESET`/`LINE`~; POKE still works.
  2. ~**Sprites (minimal)**~ — `LOADSPRITE` / `UNLOADSPRITE` / `DRAWSPRITE` (persistent pose, z-order, optional `sx,sy,sw,sh` crop) / `SPRITEVISIBLE` / `SPRITEW`/`SPRITEH` / `SPRITECOLLIDE` in basic-gfx + canvas WASM; PNG alpha over text/bitmap; paths relative to `.bas` directory. ~Worked example: `examples/gfx_game_shell.bas` (PETSCII map + PNG player/enemy/HUD), `examples/gfx_sprite_hud_demo.bas`, `examples/player.png`, `examples/enemy.png`, `examples/hud_panel.png`.~ ~Tilemap **`LOADSPRITE`** with **`tw, th`** + **`DRAWSPRITETILE`** / **`SPRITETILES`** / **`SPRITEFRAME`** — done.~
  3. ~**Joystick / joypad / controller input**~ — **`JOY(port, button)`** / **`JOYSTICK`** / **`JOYAXIS(port, axis)`** — **basic-gfx** (Raylib) + **canvas WASM** (browser gamepad buffers). See `examples/gfx_joy_demo.bas`.
  4. **Graphic layers and scrolling** — ~**Viewport `SCROLL dx, dy`** + **`SCROLLX()`/`SCROLLY()`** (single shared offset for text/bitmap + sprites) — done.~ Full **per-layer** stack (background vs tiles vs HUD) still open.
  5. ~**Tilemap handling (sheet)**~ — **`LOADSPRITE slot, "path.png", tw, th`** + **`DRAWSPRITETILE slot, x, y, tile_index [, z]`** + **`SPRITETILES(slot)`**. Full world tile *grid* storage in BASIC still manual.
  6. **Sprite animation** — ~Per-slot frame via **`SPRITEFRAME`** + tile-aware **`DRAWSPRITE`** — done.~ Optional frame rate / timing helpers still open.
  7. **Blitter-style ops, off-screen buffers, grab-to-sprite, export** — Not started. Draft design (phased: `IMAGE COPY` / off-screen 1bpp surfaces → `TOSPRITE` → PNG/raw export; CLI + WASM parity). **`docs/rgc-blitter-surface-spec.md`**. Goal: STOS/AMOS-like map/sprite **utilities written in BASIC**; README link deferred while the design is discussed.
  8. ~**Periodic timers (“IRQ-light”)** — `TIMER id, ms, FuncName` / `TIMER STOP|ON|CLEAR id`; 12 max timers, 16 ms min interval, cooperative dispatch between statements, skip-not-queue re-entrancy guard. Works in terminal, basic-gfx, and WASM. Designed as AMAL alternative (see `docs/rgc-blitter-surface-spec.md` §6). **Done.**~

* **Browser / WASM** (see `docs/browser-wasm-plan.md`, `web/README.md`, `README.md`)
  * ~**Emscripten builds**~ — `make basic-wasm` → `web/basic.js` + `basic.wasm`; `make basic-wasm-canvas` → `basic-canvas.js` + `basic-canvas.wasm` (GFX_VIDEO: PETSCII + `SCREEN 1` bitmap + PNG sprites via `gfx_software_sprites.c` / stb_image, parity with basic-gfx). Asyncify for `SLEEP`, `INPUT`, `GET` / `INKEY$`.
  * ~**Demos**~ — `web/index.html` (terminal output div, inline INPUT, `wasm_push_key`); `web/canvas.html` (40×25 / 80×25 PETSCII canvas, shared RGBA buffer + `requestAnimationFrame` refresh during loops/SLEEP).
  * ~**Controls**~ — **Pause** / **Resume** (`Module.wasmPaused`), **Stop** (`Module.wasmStopRequested`); terminal sets `Module.wasmRunDone` when `basic_load_and_run` finishes. Cooperative pause at statement boundaries and yield points (canvas also refreshes while paused).
  * ~**Interpreter fixes for browser**~ — e.g. FOR stack unwind on `RETURN` from `GOSUB` into loops; `EVAL` assignment form; terminal stdout line-buffering for `Module.print`; runtime errors batched for `printErr` on canvas.
  * ~**CI**~ — GitHub Actions WASM job uses **emsdk** (`install latest`), builds both targets, runs Playwright: `tests/wasm_browser_test.py`, `tests/wasm_browser_canvas_test.py`.
  * ~**Deploy hygiene**~ — `canvas.html` pairs cache-bust query on `basic-canvas.js` and `basic-canvas.wasm`; optional `?debug=1` for console diagnostics (`wasm_canvas_build_stamp`, stack dumps).
  * ~**Tutorial embedding**~ — `make basic-wasm-modular`; `web/tutorial-embed.js` + `RgcBasicTutorialEmbed.mount()` for **multiple** terminal instances per page. Guide: **`docs/tutorial-embedding.md`**. Example: `web/tutorial-example.html`. CI: `tests/wasm_tutorial_embed_test.py`, `make wasm-tutorial-test`.
  * ~**IDE tool host (canvas WASM)**~ — **`basic_load_and_run_gfx_argline`** exported; **`ARG$(1)`** … for bundled **`.bas`** tools (e.g. PNG preview). Spec: **`docs/ide-wasm-tools.md`**. Host IDE still needs UI wiring (click `.png` → write MEMFS → call export).
  * ~**WASM `EXEC$` / `SYSTEM` → host JS**~ — **`Module.rgcHostExec`** hook for IDE tools (uppercase selection, etc.). Spec + checklist: **`docs/wasm-host-exec.md`**.
  * ~**HTTP → MEMFS / binary I/O (for IDE tools & portable assets)**~ — **`HTTPFETCH url$, path$`** (WASM + Unix/`curl`), **`OPEN`** with **`"rb:"`/`"wb:"`/`"ab:"`**, **`PUTBYTE`/`GETBYTE`**. IDE can still **`FS.writeFile`** without interpreter changes. Notes: **`docs/http-vfs-assets.md`**.
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
| **11** | Bitmap/sprites (remaining) | Layers, scrolling, sprite animation — see sprite plan. (`SPRITECOLLIDE`, tile sheet `LOADSPRITE`, `JOY`/`JOYAXIS` done.) |
| **Later** | Optional debug logging (load + exec) | `-debug load`, `-debug exec`; verbose but useful for diagnostics. |
| **Later** | Program preprocessor | Polish; niche. |
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

---

## Engineering / tooling follow-ups (optional)

Low-urgency cleanups noted during the April 2026 parser/CI hardening pass. None block features; bank them for a quiet afternoon.

* **Broader non-gfx statement fallback audit.** Only `statement_poke`'s terminal-build fallback was buggy (eating `: stmt` via `*p += strlen(*p)`); fixed in the commit adding `tests/then_compound_test.bas`. PSET/SCREEN/etc. raise runtime errors instead, which is the correct shape. Worth a second pass over every `#ifdef GFX_VIDEO` … `#else` block in `basic.c` to confirm none of the gfx-only statements *silently* swallow the rest of the line on terminal builds — the pattern is easy to miss and only bites with `IF cond THEN <stmt> : <stmt>`.

* **Sprite / sound statement body audit.** Separate from the `*p += N` keyword-skip audit (all 68 sites passed). Statements like `LOADSPRITE`, `DRAWSPRITE`, `SPRITEVISIBLE`, `SPRITEFRAME`, `LOADSOUND`, `PLAYSOUND` etc. have non-gfx-build fallbacks that should also parse-and-discard their args (same fix shape as POKE) so they compose cleanly inside `IF … THEN … : …`. Low risk but easy to forget until a user hits it.

* **Mouse-demo Step 3 revisit.** `examples/gfx_mouse_demo.bas` line 300 / 350 were rewritten to use GOSUB while the THEN+comma-args bug was still live. Now that it's fixed, those could fold back to inline form:
  * `300 IF ISMOUSEBUTTONDOWN(0) AND ISMOUSEBUTTONDOWN(1) THEN MOUSESET 160, 100 : WARPSHOW = 6`
  * `350 IF ZONE <> LASTZONE THEN SETMOUSECURSOR ZONE : LASTZONE = ZONE`
  Verify with the native demo (raylib) before landing — line 300 also touches WARPSHOW which was a later addition.

---

## BUFFER type — large-data companion to strings

Full design in **`docs/buffer-type-plan.md`**. `HTTP$` / `JSON$` silently cap at `MAX_STR_LEN` (4 KB) because every `struct value` carries an inline `char str[MAX_STR_LEN]`. Raising the cap grows every stack frame — non-starter. Instead: a BUFFER is a RAM-disk file. `BUFFERNEW B` allocates a slot and creates `/tmp/rgcbuf_NNNN`; `BUFFERFETCH B, url$` HTTPs into it; `BUFFERPATH$(B)` returns the path so programs use existing `OPEN`/`LINE INPUT #`/`GET #`/`CLOSE` verbs to stream through it. Canvas WASM gets this for free via Emscripten's MEMFS (already on; `HTTPFETCH` already writes there). Native uses real `/tmp`. Zero changes to `open_files[]`, `struct value`, or any existing file-I/O verb — BUFFER rides on top.

**Rollout:**

* **Step 1 — core slot table + `BUFFERNEW`/`BUFFERFETCH`/`BUFFERFREE`/`BUFFERLEN`/`BUFFERPATH$`.** Users fetch big blobs, read chunk-by-chunk with existing verbs. Unblocks `bins.bas` style demos. Regression tests: `tests/buffer_basic_test.bas`, `tests/buffer_slots_test.bas`.

* **Step 2 — `JSONFILE$(path$, jpath$)`.** One function; reuses existing `json_extract_path` against file bytes. Eliminates the "slurp 50 KB into a 4 KB string" anti-pattern.

* **Step 3 — `RESTORE FILE path$` / `RESTORE BUFFER slot`.** Retargets DATA/READ to scan a file/buffer. Bigger change — second `data_items` source or streaming tokenizer. Not urgent.

**Open questions in the doc:** Windows `/tmp` path, MAX_BUFFERS ceiling (16 vs 64), whether `BUFFERFETCH` should accept `file://` URLs to subsume a future `BUFFERLOAD`.

---

## Mouse-over-sprite hit test + `SPRITEAT` + drag-and-drop

Full design in **`docs/mouse-over-sprite-plan.md`**. Summary: today a BASIC-level `MOUSEOVER(sx, sy, sw, sh)` helper (documented in the README) covers the bounding-box case using `GETMOUSEX/Y` + `SPRITEW/H`. An engine-level API earns its keep for three cases BASIC can't do cleanly:

* **`ISMOUSEOVERSPRITE(slot)`** — hit-test against the slot's last-drawn rect; engine remembers the position so programs don't have to. Optional `ISMOUSEOVERSPRITE(slot, 1)` samples the PNG's alpha channel for pixel-perfect round-button / irregular-shape hit testing.
* **`SPRITEAT(x, y)`** — returns the topmost visible slot whose rect contains the point, or `-1`. Useful for "click to select from a pile" in RTS unit stacks or inventory.
* **Consistency with `SCROLL` and `SPRITECOLLIDE`** — hit test respects `SCROLLX()/SCROLLY()` so sprite positions stay in world space while mouse coords are screen space, matching how `SPRITECOLLIDE` already works.

Implementation sequence in the plan doc: (1) per-slot `last_x/y/w/h` cache updated at `DRAWSPRITE`/`DRAWSPRITETILE` enqueue time, (2) `ISMOUSEOVERSPRITE` bounding-rect mode + keyword wiring + RTS-button demo, (3) pixel-perfect mode, (4) `SPRITEAT` iteration with z-sort, (5) drag-and-drop example (pure BASIC on top of the new API), (6) canvas WASM parity.

**Shipped (unreleased):**

* ~**Steps 1 + 2 + 6 — per-slot position cache + `ISMOUSEOVERSPRITE(slot)` bounding-rect hit test, native and canvas WASM.**~ `g_sprite_draw_pos[]` written on the interpreter thread inside `gfx_sprite_enqueue_draw` (so it doesn't race the worker-thread consumer); sw/sh ≤ 0 resolved via `gfx_sprite_effective_source_rect` for SPRITEFRAME / tilemap slots; `UNLOADSPRITE` clears the entry. `basic.c`: `FN_ISMOUSEOVERSPRITE = 62`, name lookup, `eval_factor` dispatch, `starts_with_kw` allow-list. Example: `examples/ismouseoversprite_demo.bas`.

**Still outstanding:** pixel-perfect mode (step 3), `SPRITEAT` (step 4), drag-and-drop example (step 5), SCROLL-space consistency, rotation/scale pivot handling.

Open questions in the doc: alpha cutoff threshold, source-rect vs destination-rect sampling for scaled sprites, last-draw persistence across non-drawn frames, rotation/transform future-proofing.

## Text in bitmap mode + pixel-space `DRAWTEXT`

Full design in **`docs/bitmap-text-plan.md`**. Split into two halves: character-set rendering in bitmap mode (done), and the new Font / `DRAWTEXT` system (outstanding).

**Shipped (post-1.6.3, unreleased):**

* ~**Step 1 — `gfx_video_bitmap_clear` + `gfx_video_bitmap_stamp_glyph` helpers; `CHR$(147)` routes on `screen_mode`.**~
* ~**Step 2 — `PRINT` / `TEXTAT` render into `bitmap[]` via the active chargen when `screen_mode == GFX_SCREEN_BITMAP`.** Solid paper so over-prints overwrite cleanly; text plane untouched in bitmap mode per spec.~
* ~**Step 3 — Bitmap-mode scroll on PRINT overflow.** `gfx_video_bitmap_scroll_up_cell` shifts the plane up 8 pixel rows via `memmove` and zeros the bottom cell; text-mode `gfx_scroll_up` unchanged.~

Result so far: programs that `PRINT` a HUD, score, or status line in `SCREEN 1` now render exactly as they would in `SCREEN 0`, using the same chargen. Good for tutorial examples before Fonts arrive.

**Outstanding:**

* **Step 4 — `DRAWTEXT x, y, text$ [, fg [, bg [, font_slot [, scale]]]]`.** Pixel-space rendering. PETSCII-free — bytes in `text$` are raw Font-glyph indices (no control-code interpretation, no wrap, no screen-clear on 147). Per-call fg/bg (bg = -1 transparent). Integer `scale` ≥ 1, nearest-neighbour pixel-doubling. MVP colour path: temporarily override `gfx_vs->pen`/`paper` for the call.

* **Step 5 — `LOADFONT slot, "path.rgcfont"` / `UNLOADFONT slot`.** Reads the 8-byte `RGCF` magic header (width, height, glyph count) and the bitmap payload that follows. Fonts live in a separate `Font fonts[N]` array on `GfxVideoState` — entirely distinct from the active character set, which keeps its existing storage and layout. Slot 0 is the built-in default Font (a Font-copy of the 8×8 PET artwork); swapping the active character set does not touch it.

* **Step 6 — Canvas WASM Playwright parity.** One Playwright case for `SCREEN 1 : PRINT "HI"`, one for `SCREEN 1 : DRAWTEXT 100, 50, "HI", 7`.

* **Intermediate: offline converter tool `tools/pngfont2rgc`.** Turns a bitmap-font PNG into the `.rgcfont` format `LOADFONT` consumes. Keeps the interpreter's Font loader to a header-read plus one `fread`; lets users edit in Aseprite/GIMP/Photoshop, export PNG, convert, load. Uses `stb_image.h` already in `gfx/`. Optional `.py` companion for single-script edit+convert. Examples in `examples/fonts/` (8×8 default, 8×16 slim, 16×16 chunky, 16×16 bold).

* **Terminology reminder (locked in the spec):** **character set** (lowercase, 8×8×256, PETSCII-indexed, drives `PRINT`/`LOCATE`/`TEXTAT`/`CHR$(147)` — already wired for bitmap mode); **Font** (capital F, arbitrary dimensions, PETSCII-free, `DRAWTEXT`-only, loaded via `LOADFONT`). The two concepts don't share storage, structs, or loaders. Sizing: per-slot native dimensions (different sizes = different Fonts) vs render-time integer scale (pixel-doubling at draw time). Weights ship as separate Fonts with their own artwork — no algorithmic fake-bold.

* **Resolved open questions** (from the spec): PETSCII normalisation applies only to the character-set path (inherits from PRINT's existing flow); `DRAWTEXT` never normalises. Cursor in bitmap mode is a no-op for now — character-set-scope only, trivial XOR-stamp revival if anyone asks. 80-col is text-mode only; bitmap character-set path is forever 40×25.

