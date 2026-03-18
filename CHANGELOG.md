## Changelog

### Unreleased

(Future changes go here.)

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

