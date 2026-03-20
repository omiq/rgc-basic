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

* **MEMSET, MEMCPY** (basic-gfx; see `docs/memory-commands-plan.md`)
  * XC=BASIC-style: `MEMSET addr, len, val`; `MEMCPY dest, src, len`. Operate via gfx_peek/gfx_poke on virtual address space.
  * **MEMSHIFT not needed**: Implement MEMCPY with overlap handling (like memmove); covers both directions.

* ~**LOAD INTO memory**~ (basic-gfx; see `docs/load-into-memory-plan.md`) — implemented:
  * `LOAD "path" INTO addr [, length]` — load raw binary from file.
  * `LOAD @label INTO addr [, length]` — load from DATA block at label.
  * Terminal build: runtime error "LOAD INTO requires basic-gfx".

* **80-column option** (terminal and basic-gfx)
  * `#OPTION columns 80` / `-columns 80`; default 40.
  * **Terminal**: Configurable `print_width`; wrap, TAB, comma zones (10 vs 20). ~1–2 hrs.
  * **basic-gfx**: 80×25 screen buffer (2000 bytes); configurable cols; raylib window 640×200 or scaled. ~4–8 hrs.

* PETSCII symbols & graphics
  * ~Unicode stand-ins~
  * ~Bitmap rendering of 40×25 characters (raylib)~ — **basic-gfx** merged to main.
  * ~Memory-mapped screen/colour/char RAM, POKE/PEEK, PETSCII, `.seq` viewer with SCREENCODES ON~

* **Bitmap graphics & sprites** (incremental; see `docs/bitmap-graphics-plan.md`, `docs/sprite-features-plan.md`)
  1. **Bitmap mode** — `SCREEN 1` (320×200 hires), bitmap RAM at BITMAP_BASE; monochrome renderer. Enables pixel drawing via POKE, later `PSET`/`LINE` helpers.
  2. **Sprites (minimal)** — `LOADSPRITE slot, "path"`, `DRAWSPRITE slot, x, y [, z]`, `SPRITEVISIBLE slot, on`. PNG load, Z-ordered draw queue. Collision: `SPRITECOLLIDE(slot1, slot2)`.
  3. **Joystick / joypad / controller input** — Poll gamepad via raylib; expose to BASIC as `JOY(port)` or similar read API for D-pad, buttons, axes. Support keyboards-as-joystick and real controllers.
  4. **Graphic layers and scrolling** — Layer stack (background, tiles, sprites, text) with independent scroll offsets; `SCROLL x, y` or per-layer scroll; camera/viewport for games.
  5. **Tilemap handling** — `LOADSPRITE slot, "path", "tilemap"`; define tile size (e.g. 16×16); render tile grid from sprite sheet. Efficient level/world rendering.
  6. **Sprite animation** — Multiple frames per slot; `SPRITEFRAME slot, n` or frame parameter in `DRAWSPRITE`; optional frame rate / timing.

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

* **String & array utilities** (see `docs/string-array-utils-plan.md`) — SPLIT, REPLACE, INSTR start, INDEXOF, SORT, TRIM$, JOIN, FIELD$, ENV$, JSON$. Key-value emulation via SPLIT+FIELD$; no dedicated DICT type for now.
  * **SPLIT** — `arr$ = SPLIT(csv$, ",")` — split string by delimiter into array.
  * **REPLACE** — `result$ = REPLACE(original$, "yes", "no")`.
  * **INSTR start** — `INSTR(str$, find$, start)` — optional start position for find-next loops.
  * **INDEXOF / LASTINDEXOF** — `INDEXOF(arr, value)` — 1-based index in array, 0 if not found.
  * **SORT** — `SORT arr [, mode]` — in-place sort; asc/desc, alpha/numeric.
  * **TRIM$** — strip leading/trailing whitespace (CSV, input).
  * **JOIN** — inverse of SPLIT: `JOIN(arr$, ",")`.
  * **FIELD$** — `FIELD$(str$, delim$, n)` — get Nth field (awk-like).
  * **ENV$** — `ENV$(name$)` — environment variable.
  * **PLATFORM$** — `PLATFORM$()` — returns `"linux-terminal"`, `"linux-gfx"`, `"windows-terminal"`, `"windows-gfx"`, `"mac-terminal"`, `"mac-gfx"`. Enables conditional code for paths/behavior.
  * **JSON$** — `JSON$(json$, path$)` — path-based extraction from JSON string (no new types); e.g. `JSON$(j$, "users[0].name")`.

---

## Suggested priorities & sequence (post bash/PETSCII)

| Order | Item | Rationale |
|-------|------|------------|
| **1** | String length limit | Foundation; SPLIT, JSON, file I/O need larger strings. Small change. |
| **2** | String utils batch 1: INSTR start, REPLACE, TRIM$ | Quick wins; no new types; high impact for CSV/shell. |
| **3** | RESTORE [line] | Tiny; useful for DATA-heavy programs. |
| **4** | LOAD INTO memory | GFX; unblocks charsets/sprites. Can parallel with string work. |
| ~**5**~ | ~String utils batch 2: SORT, SPLIT, JOIN, FIELD$~ | Done. |
| ~**6**~ | ~INDEXOF, LASTINDEXOF~ | Done. |
| ~**7**~ | ~MEMSET, MEMCPY~ | Done. |
| **8** | ENV$, PLATFORM$, JSON$ | ENV$ and PLATFORM$ done. JSON$ needs parser. |
| **9** | 80-column option | Improves legibility. |
| **10** | Bitmap/sprites | Bigger phase; depends on LOAD. |
| **Later** | Program preprocessor, #OPTION memory, Browser/WASM | Polish; niche; different target. |

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

