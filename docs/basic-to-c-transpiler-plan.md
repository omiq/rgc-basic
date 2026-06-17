# RGC-BASIC → C output (cc65 / z88dk) — design notes

This document sketches how the **RGC-BASIC** front end could be extended with a **C code generator** so programs can be compiled with **cc65** (6502 targets) or **z88dk** (Z80 and others), instead of (or in addition to) interpretation.

It is **not** implemented today; it is a roadmap for a **subset compiler / transpiler** with a **portable C** intermediate step.

> **⚠️ 2026-06-16 — read this first. The screen-output model below is superseded.**
> This doc was written *before* the `~/github/retro-c` roguelike proved one C codebase
> builds on every computer the IDE supports (~16 machines, 6 compilers), and *before*
> we decided to **drop the console/serial and tilemap-console directions**. The
> **language subset, exclusions, and `GOTO` lowering below all still stand** — but the
> output target has changed: the text-game tier emits against **retro-c's `platform.h`
> contract** (positioned per-cell output), **not** a generic stdout/serial `basrtl.c`.
> So entries below that exclude `LOCATE`/`TEXTAT`/positioned drawing as "platform-tied"
> are reversed for this tier. See **§ Text-game tier (2026-06-16 reconciliation)** at the
> end of this document for the live plan.

---

## Goals

1. **Emit C source** that compiles with a standard C toolchain aimed at 8-bit hosts.
2. **Share parsing and semantic analysis** with the interpreter where possible (same token/AST/IR story).
3. **Document explicitly** what must be **excluded** or **restricted** so generated code is realistic on cc65/z88dk.

---

## Why C first (not raw 6502/Z80 asm)

- **One backend** for many CPUs: cc65 (6502), SDCC/z88dk (Z80), etc.
- **Runtime in C**: `printf`, string helpers, and math can live in `basrtl.c` and be tuned per platform.
- **Asm later**: once a stable IR exists, a direct assembler backend is optional.

---

## Architecture (high level)

| Stage | Role |
|--------|------|
| Lex / parse | Same as today; optionally build an **AST** or **IR** instead of immediate execution. |
| Semantic pass | Type/size rules for the **compilable subset**; reject unsupported constructs with clear errors. |
| C codegen | Walk IR → `functions`, `static` data for `DATA`, `switch`/labels for `GOTO`, etc. |
| `basrtl.h` / `basrtl.c` | **Runtime**: string pool or heap policy, `INPUT`/`PRINT` stubs, optional fixed-point math. |

The interpreter’s execution functions (`statement_*`, `eval_*`) are **not** reused as-is for codegen; they inform **what** to emit for each construct.

---

## Recommended compilable subset (phase 1)

Aim for programs that look like **structured BASIC** with **integers** and **simple strings**.

**Statements (initial)**

- `REM` / `'`
- Assignment (`LET` optional)
- `PRINT` with `;` and `,` (map `,` to tab logic or simplified spacing)
- `IF … THEN` (line and block `IF` / `ELSE` / `END IF`) — **no** `THEN` line-number-only goto unless lowered to `goto`
- `FOR` / `NEXT` with numeric loop variable and `STEP`
- `WHILE` / `WEND`, `DO` / `LOOP` / `LOOP UNTIL` / `EXIT`
- `GOTO` / `GOSUB` / `RETURN` with **labels** (emit C `goto` / functions — see below)
- `END` / `STOP`
- `DIM` for **fixed** 1D arrays (numeric and string), bounds known at compile time
- `READ` / `DATA` / `RESTORE` (static data tables in C)
- `DEF FN` for **single-line** numeric functions only (phase 1)

**Expressions (initial)**

- Integer and float **literals**; prefer **16-bit `int`** or **`long`** policy per target
- `+ - * /`, parentheses
- Relational operators in `IF`
- **Intrinsic functions (numeric, phase 1):** `ABS`, `INT`, `SGN`, `SQR` (via `sqrt` if lib linked), `RND` (runtime LCG)

**Strings (phase 1, restricted)**

- Fixed maximum length (e.g. 40 or 80) → `char name[N+1]` or pooled buffers
- `LEFT$`, `RIGHT$`, `MID$`, `LEN`, `CHR$`, `ASC`, `STR$`, `VAL` with **bounded** temporaries
- Concatenation `A$ + B$` only if result fits static policy

---

## Features to **exclude** or **defer** (explicit)

These are either **host-specific**, **dynamic**, or **too heavy** for a first cc65/z88dk pipeline. The transpiler should **reject** them with a clear diagnostic (not silently miscompile).

### Meta and loader

| Feature | Reason to exclude (v1) |
|--------|-------------------------|
| `#INCLUDE` | Needs a compile-time file merge step; use a preprocessor or single concatenated source for the demo. |
| `#OPTION …` | Maps to CLI/cc65 pragmas; handle as **comments** or **separate build flags**, not generated C. |
| Shebang | Strip or ignore. |

### Host / OS / shell (no portable C equivalent on 8-bit without a full OS)

| Feature | Reason |
|--------|--------|
| `SYSTEM`, `EXEC$` | Subprocess/shell — exclude. |
| `ENV$` | Environment variables — exclude unless stubbed empty. |
| `ARGC` / `ARG$` | Could map to `main(argc, argv)` **only** if the emitted program defines `main` and the harness passes args — document as **optional** phase 2. |

### Dynamic execution

| Feature | Reason |
|--------|--------|
| `EVAL(expr$)` | Runtime parse/eval — exclude unless embedding a tiny interpreter (out of scope for v1). |

### Advanced strings and data formats

| Feature | Reason |
|--------|--------|
| `JSON$` | Exclude; large runtime. |
| `REPLACE`, `TRIM$`, `LTRIM$`, `RTRIM$`, `FIELD$` | Can add to `basrtl` later; exclude v1 or implement as C helpers with fixed buffers. |
| `SPLIT` / `JOIN` | Heap/variable field counts — defer or static-max only. |
| `STRING$(n, c)` | OK if `n` is **constant**; exclude if `n` is dynamic beyond max. |

### Arrays and advanced control

| Feature | Reason |
|--------|--------|
| `SORT` | Needs qsort-style helper or typed sort in runtime — defer or single-type v1. |
| `INDEXOF` / `LASTINDEXOF` | Linear search in `basrtl` — optional phase 2. |
| Multi-line `FUNCTION` / `END FUNCTION`, recursion | Needs calling convention and stack — **defer**; allow **DEF FN** one-liners first. |
| `ON expr GOTO` / `GOSUB` | Lower to `switch`/`if` chain — possible in phase 2. |

### Graphics, video memory, sprites (basic-gfx / canvas)

| Feature | Reason |
|--------|--------|
| `SCREEN`, `PSET`, `PRESET`, `LINE`, `COLOR`, `BACKGROUND`, `LOCATE`, `TEXTAT`, `DRAWSPRITE`, `LOADSPRITE`, etc. | Tied to **GfxVideoState** / platform — **out of scope** for generic C unless targeting a **specific** library (e.g. one SDL or one console API) as a **separate** backend. |
| `POKE` / `PEEK` (screen or fake RAM) | Exclude or map to a **named** `uint8_t mem[]` region in generated C if you add a **memory model** later. |
| `LOAD` … `INTO`, `MEMSET`, `MEMCPY` | binary/GFX — exclude for generic C. |

### File I/O

| Feature | Reason |
|--------|--------|
| `OPEN` / `PRINT#` / `INPUT#` / `GET#` / `CLOSE` / `ST` | C11 `fopen` may exist on some hosted targets; on **bare** cc65, I/O is platform-specific — **exclude** in v1 or emit **stubs** (`putc`/`getc` to serial only) behind `#ifdef`. |

### Interpreter-only or platform-variable semantics

| Feature | Notes |
|--------|--------|
| `TI` / `TI$` | **Jiffy clock** — exclude or replace with a **`unsigned long` tick** updated by a **platform timer** stub (`basrtl_tick()` in IRQ). |
| `PLATFORM$()` | Emit a **string constant** at compile time or stub `"c-generated"`. |
| `RND` | Emit **LCG** in runtime; document seed policy. |
| `SLEEP` | Map to **busy-wait** or **timer** stub per target. |
| `CURSOR ON/OFF` | Terminal/ANSI only — exclude for bare metal or wrap in `#ifdef CONSOLE`. |

### Floating point

- **cc65** float support is limited/slow; **z88dk** has floats but size/speed cost.
- **Recommendation:** Phase 1 = **integers only** or **fixed-point** (`typedef int16_t fixed_t` with fixed shift). Exclude `SIN`/`COS`/… unless linking **libm** and accepting code size — or provide **integer trig tables** for demos only.

### PETSCII tokens in strings `{RED}` etc.

- **Source transform** exists in the interpreter; for C output either:
  - **pre-expand** to `CHR$(n)` / concatenation in the emitter, or  
  - exclude and require **ASCII** literals in v1.

---

## `GOTO` / `GOSUB` lowering

- **Labels → `goto`** in C: valid for **one function** if all labels live in the same generated `main` or one mega-function (cc65 supports `goto` within a function).
- **GOSUB → `void` functions** or **inline call + return label** — needs stack discipline; **phase 1** can require **structured** code (no `GOSUB`) or only **forward** `GOSUB` to named subs lowered to C functions manually.

Document a **style guide** for “compilable BASIC” (e.g. prefer `WHILE`/`FOR` over `GOTO`).

---

## Output layout

Suggested emitted files:

- `program.c` — generated code
- `basrtl.c` / `basrtl.h` — runtime (optional static link)
- `Makefile` or documented **cc65** / **z88dk** invocations

---

## Testing strategy

1. **Golden tests**: small `.bas` files → run transpiler → compile with cc65 (sim) or host `gcc -Wall -Werror` first.
2. **Compare** numeric output with **interpreter** on the same inputs for accepted programs.
3. Expand subset only when tests exist.

---

## Relation to this repository

- **Parser / AST**: future work; today execution is fused with parsing.
- **This doc** fixes **expectations** and **exclusions** for anyone implementing `basic2c` or similar.

---

## References

- [cc65](https://cc65.github.io/) — C compiler and assembler for 6502.
- [z88dk](https://www.z88dk.org/) — C and asm for Z80 family.
- `docs/user-functions-plan.md` — full **FUNCTION** semantics in the interpreter (heavy for codegen v1).
- `docs/meta-directives-plan.md` — `#OPTION` / `#INCLUDE` (treat as build-time, not runtime C).

---

## § Text-game tier (2026-06-16 reconciliation)

**Status:** live plan. Supersedes the *screen-output* parts of the v1 sketch above
(the language subset / exclusions / `GOTO` lowering above are unchanged and still apply).

### What changed and why

1. **The runtime contract already exists and is proven.** `~/github/retro-c/platform/
   platform.h` is the portable contract the v1 doc imagined as a hand-written
   `basrtl.c`. It is implemented on **6 C compilers across ~16 machines** (cc65 6502
   family, vbcc 68k, cmoc 6809, sdcc z80, z88dk zx, SmallerC x86) and **every machine
   in the IDE dropdown**. We emit against it instead of inventing a new runtime.
2. **Console/serial output is dropped.** The v1 "PRINT → stdout / serial `putc`"
   model assumed hosted or serial targets. Bare 8-bit micros render to **screen
   memory**, not a console. The text-game tier targets the **screen**, per-cell.
3. **Tilemap/console-tier systems are out of scope** (decided alongside the retro-c
   target work): NES/GB/Coleco/SMS/Megadrive/SNES etc. **Text-display computers only.**
   So no tile/sprite VRAM model to design — the `platform.h` text contract is enough.
4. **Therefore positioned drawing is now IN scope** (v1 excluded `LOCATE`/`TEXTAT` as
   "platform-tied"): it is exactly what `platform.h` provides, portably.

### Output target

Generated C is **`game`-shaped** (matches retro-c's `game/*.c`): it `#include
"platform.h"`, defines a `main`/entry that calls `plat_init()` then runs, and draws
via the contract functions. The IDE bundler `retro-c/scripts/bundle-ide-demo.py`
already inlines `game + plat_<target>.c` into one `.c` per IDE preset — the transpiled
program slots in where `game/*.c` was. **No new `basrtl.c`**; the "runtime" is
`platform.h` + the per-target adapter.

#### ZX Spectrum target — VERIFIED 2026-06-17

Emitted C compiles + renders on ZX (z88dk) against `plat_zxspectrum.c`. Build recipe
(see retro-c notes + `memory/reference_zx_z88dk_c_recipe.md`):
`zcc +zx -compiler=sdcc --reserve-regs-iy -lndos --math32 -pragma-define:CLIB_OPT_PRINTF=0xffffffff -create-app`
- `procgen.bas` → emit_c → C → recipe → renders its 16×8 map (verified headless via z88dk-ticks).
- `move.bas` builds + fits (~11KB); valid on real ZX (getkey-driven).
- `trek-portable.bas` compiles **clean** but is ~71KB (float + large game) → exceeds the ZX's 64K. It fits cc65/cmoc/sdcc(MSX) which have more headroom or fixed-point `rgc_real`. **ZX is a small-program target; trek-class programs are too big.**

Emitter constraint surfaced: the **SmallerC (x86) backend rejects long expressions**
("expression too long"). The emitter's parenthesised `&&`/`||` chains top out at ~4
terms (smlrc-safe); only hand-written code with long flat chains hit it. If a `.bas`
ever yields a long `AND`/`OR` chain, split it into per-condition statements in the
emitter — future hardening.

### Existing contract (retro-c `platform.h`, do not redefine)

```c
void    plat_init(void);
uint8_t plat_screen_w(void);
uint8_t plat_screen_h(void);
void    plat_cls(void);
void    plat_putc(uint8_t x, uint8_t y, glyph_t g, uint8_t colour);   /* logical glyph */
void    plat_puts(uint8_t x, uint8_t y, const char *s, uint8_t colour);
uint8_t plat_key_pressed(void);   /* 0 = none; else logical key code K_* */
uint8_t plat_key_wait(void);
```

### Tier-1 needs NO contract change — `TEXTAT` maps to existing `plat_puts`

**Verified 2026-06-16** in `basic.c` and the adapters. rgc-basic's write verb is
`TEXTAT x, y, text` (a **string**, `basic.c:15407`), and `platform.h` already has
`plat_puts(x, y, const char *s, colour)`, which draws a **raw string** at a cell **and
does the ascii→native conversion on every adapter** (checked: `plat_coco3.c` `vdg_code`,
`plat_c64.c` case-flip + `cputcxy`, `plat_msx.c` `vram_putc`). So:

```
TEXTAT x, y, "#"   →   plat_puts(x, y, "#", COL_DEFAULT)
```

A single character is just a length-1 string. **No new `platform.h` function, no
multi-adapter edit, nothing gated behind the clean-reference guardrail.** Milestone 1 is
pure parser→emit plumbing against the contract as it already exists. (c64 charset quirk:
`plat_puts` case-flips letters A↔a — irrelevant for `#`/`@`; just know letters render in
swapped case on c64, same as the game.)

### Deferred / optional: `plat_putc_raw` and `SCREENCHAR`

Two things we *thought* were on the critical path but are not:

- **`plat_putc_raw(x,y,ascii,colour)`** — a single-cell raw-char write (or char **by
  numeric code**). `plat_puts` covers the string case, so this is only an *optimization*
  (per-cell, or `CHR$`-style numeric codes) — add later if a program needs it, on the
  pilot adapters first, per the extend-don't-ifdef guardrail. **Not** a Tier-1 blocker.
- **`SCREENCHAR`** — the project notes reserve this name for a *read* primitive ("char at
  cell", for collision). Separate, deferred, and per the array-map authoring insight
  (collide against a `map[][]` array, not by peeking the screen) it may never be needed.
  Nothing to do with the write path.

### Tier-1 minimal command set (locked 2026-06-16)

"One step past hello world": non-interactive, deterministic, screenshot-verifiable on
every target. Just enough to test **statement emission + control flow + coordinate
addressing + runtime mapping** — defers input, `IF`, RND, arrays to Tier 2.

| BASIC | Emits | Notes |
|--|--|--|
| `CLS` | `plat_cls()` | already in contract |
| `TEXTAT x, y, s` | `plat_puts(x, y, s, COL_DEFAULT)` | already in contract; 1-char string is fine |
| `FOR v = a TO b [STEP s]` / `NEXT` | C `for` | integer loop var |
| integer var + assign + literal | C `int` / `int16_t` | per the v1 size policy |

Reference Tier-1 program (draws a wall row + `@`, identical on all targets):

```basic
10 CLS
20 FOR X = 0 TO 9
30 TEXTAT X, 0, "#"
40 NEXT X
50 TEXTAT 4, 2, "@"
```

**END semantics (decided 2026-06-16):** the emitted program **returns to READY/OS**, leaving
the screen as drawn — faithful BASIC. The transpiler injects **nothing** at END: no
screen-clear, no auto-pause, no hold loop. If the author wants the screen held or a
keypress wait, they write it in BASIC (infinite loop / `GET`-style wait — Tier-2 verbs).
This keeps the transpiler faithful/dumb; behaviour is the program's, not the codegen's.
(The roguelike's `plat_shutdown` clrscr + `plat_key_wait` are game cleanup — deliberately
NOT emitted.)

### Milestone order

No `platform.h` edit on the critical path — Tier-1 emits against the contract as-is.

0. **Host-side PoC — DONE 2026-06-16.** `tools/rgc_lint/emit_c.py` walks the tokenizer's
   `Statement` stream and emits the Tier-1 program to C89. Proven end-to-end on the host:
   emit → `gcc -std=c89 -Wall -Werror` against a grid-stub `platform.h` → run → correct
   output (`##########` wall row + `@` at 4,2). Lints clean via `rgc_lint/cli.py` (shared
   front end); rejects non-Tier-1 keywords with a clear `EmitError`. No cross-compiler yet.
1. **(this doc)** reconcile the plan; confirm Tier-1 maps to existing `plat_cls`/`plat_puts`. ✅
2. **Tier-1 emitter — DONE (host PoC, see step 0).** `tools/rgc_lint/emit_c.py` rides the
   existing linter front end (`tokenizer.py` `Statement` stream; `rules.json` + drift guard
   for keyword-truth/tier), separate from `tools/rgc2ugb/emit.py` (the ugBASIC path).
   New code it added: `_split_args` (quote-aware comma split), `_FOR_RE`/`_ASSIGN_RE` arg
   parse, a FOR↔NEXT indent/stack for `{`/`}`, `_collect_int_vars` → C89 `int` decls at
   block top. ~150 lines. The arg-parse here is the seed that grows into the option-B AST.
3. **Real cross-compiler build — C64/cc65 DONE 2026-06-16 (compile+link).** First target
   = **C64** (Chris's pick). No bundler needed for a *local* build — mirror `Makefile.c64`:
   `cl65 -t c64 -O -Cl -I platform -I game -o tier1-c64.prg <emitted.c> platform/plat_c64.c`
   (run from retro-c root). Emitted C built clean to a 2413-byte `.prg`, no warnings — the
   transpiled output survives a real 6502 toolchain, not just host gcc. **Render pending
   Chris's eyeball** in VICE (`x64sc /tmp/tier1-c64.prg`) — CLI can't auto-confirm the emu
   window on macOS.
   - *IDE-bundle path (later):* `retro-c/scripts/bundle-ide-demo.py` is hardcoded to the
     roguelike file set; a sibling `bundle_program(plat, emitted_c)` reusing its
     `DROP_SYS`/`PREAMBLE`/strip machinery (headers = `platform.h` only; bodies =
     `plat_<plat>.c` + emitted) wires the transpiler into the IDE. Not needed for local cc65.
4. **Extend to other pilots** (cmoc/CoCo3, sdcc-or-z88dk) once C64 render is confirmed.
5. *(later, optional)* `plat_putc_raw` if a program needs single-cell / numeric-code puts.

### Tier 2 — procgen DONE 2026-06-16

`emit_c.py` v2 added, proven end-to-end on host + C64/cc65 + CoCo3/cmoc:
- **`IF <cond> THEN <stmt>`** (single line) → `if (cond) { ... }`; operator xlate
  `=`→`==`, `<>`→`!=`, `AND`→`&&`, `OR`→`||`, `NOT`→`!`, `<=`/`>=` pass through.
- **`DIM A(b1[,b2[,b3]])`** (1–3D, 0-based, size = bound+1; literal bounds folded) →
  C fixed arrays; `A(i,j)` ↔ `A[i][j]` in expressions and assignments.
- **`RND(n)` → `(plat_rand() % (n))`** (portable **integer** RND, 0..n-1). Decided
  2026-06-16: the interpreter's float `RND` (0..1, time-seeded) is NOT the oracle for the
  portable tier; the hand-C side is. Emitter auto-seeds with a **fixed non-zero constant**
  (`plat_seed_rand(1)`) when RND is used.

**Demo:** `tools/rgc_lint/examples/procgen.bas` — bordered 16×8 map, random interior walls
(DIM 2D + nested FOR + IF + RND), rendered with TEXTAT. One `.bas` → host + C64 + CoCo3, all
deterministic.

**Two gotchas banked:**
1. `plat_seed_rand(0)` is the contract's **sentinel for hardware entropy** (non-deterministic)
   — a fixed non-zero seed is required for reproducible RND.
2. The retro-c adapters **share an xorshift16 PRNG** (`s^=s<<7; s^=s>>9; s^=s<<8`), so the
   same non-zero seed yields the **identical map on every target** — cross-platform
   determinism for free (stronger than the per-platform determinism the RND decision assumed).
   The host stub uses the same LCG, so the host render **is** the oracle: C64/CoCo3 must match
   it byte-for-byte.

**Deferred (Tier-2):** a user-facing seed verb (`RANDOMIZE` doesn't exist in `basic.c`;
adding it = a drift-guarded language change). Full roguelike port = Tier 3.

### Input + strings DONE 2026-06-16

The first interactive transpiled program, on C64/cc65 + CoCo3/cmoc (+ Z80/sdcc compile).
`tools/rgc_lint/examples/move.bas` — move an `@` with WASD, `q` quits.

- **Contract add: `uint8_t plat_getkey_nb(void)`** (non-blocking RAW key, 0 = none, else
  ASCII) — `plat_key_*` collapse to logical `K_*`, which can't serve `GET A$`. Implemented
  on the 3 pilots (c64 `cgetc`, coco3 `inkey`, host); other 15 adapters = logged debt in
  `retro-c/docs/refactor-plan.md`.
- **Fixed-length string vars**: `A$` → `char A_str[41]` (STRMAX 40). Assignment (literal /
  var / `CHR$(n)`), equality in IF/WHILE (`A$="x"`, `A$<>B$`), `TEXTAT` of a string var,
  `GET A$` → `plat_getkey_nb` (empty string if no key — faithful non-blocking GET).
- **`WHILE <cond>` / `WEND`** → C `while`. Needed because `FOR` can't poll-until-quit.

**Gotcha banked: don't assume libc headers exist on retro targets.** Emitting
`#include <string.h>` + `strcpy`/`strcmp` built on cc65 but **broke cmoc** (no `string.h` →
pulled the host macOS SDK and exploded). Fix: the emitter carries its **own inline string
helpers** (`rgc_scpy`, `rgc_seq`) — zero header deps, portable across cc65/cmoc/sdcc. (These
are the seed of the future `basrtl` runtime.)

**String functions DONE 2026-06-16** (after the AST landed — each is one `to_c` case):
`UCASE$`, `LCASE$`, `LEFT$`, `RIGHT$`, `MID$` (1-based), `CHR$`, `LEN`. String-returning
functions write into a small **rotating static pool** (`rgc_pool[4]`) so they compose in
expressions (the classic BASIC string-temp idiom); `LEN` is numeric (`rgc_slen`). Helpers
are inline (no libc), emitted only when used, gated per-function (and `rgc_scpy`/`rgc_seq`
gated on actual copy/compare). `example/strings.bas` renders `HELLO/hel/ell/FIVE/A` on
host+C64+CoCo3. `UCASE$` also cleans up `move.bas`: `K$ = UCASE$(K$)` → single uppercase
compares, retiring the per-platform keyboard-case both-case hack.

**Still deferred:** string concat (`A$ + B$`), `STR$`/`VAL`, blocking input, string arrays.
Three CPU families now run transpiled BASIC with graphics, arrays, RNG, strings + string
functions, input, and loops — enough for Tier-3 (roguelike) to begin.

---

## § Architecture: the linter front end already exists — the transpiler grows on it

The clean front end the transpiler wants is **already built** as the linter in
`tools/rgc_lint/` (Python). It was designed for this from the start — `tokenizer.py`
docstring: *"for the linter and (later) transpiler … the transpiler will need a deeper
walk later but can grow on top of this."* So there is no "build the AST first" task; the
on-ramp is partly paved.

**Reused as-is for the transpiler:**

| Piece | Role for the emitter |
|--|--|
| `tokenizer.py` → `Statement` stream | line/col/`first_word`/`rest`/`is_label`/`line_num`, comments + `:`-split + CBM crunch normalization done. `Statement` already carries transpiler-intent fields (`is_label` "so the transpiler can re-emit the trailing colon", `line_num` "so the transpiler can preserve them"). |
| `rules.json` + `test_drift.sh` | keyword truth + portability **tier**, kept complete against `basic.c` (`extract_keywords.canonical_set()` from `reserved_words[]`/`eval_factor`/`kconst[]`). The tier is the **ugBASIC-portability** axis only — *not* a gate on the C emitter, which supports the whole `modern` tier (SELECT/CONTINUE/DICT all transpile, see trek milestone). `--check-transpile` answers "does this transpile to C?" by running the emitter and suppresses tier-membership diagnostics (a separate axis); the v1 "reject, don't silently miscompile" guarantee comes from the emitter raising on genuinely unsupported constructs, not from the tier. |
| `walker.py` statement-walk pattern | the shape the emitter mirrors. |
| `normalize.py` | CBM keyword-glue normalization (port of `basic.c:normalize_keywords_line`). |

**New work the emitter adds (the linter never needed it):**

1. **Expression parser → AST — option B, DONE 2026-06-16 (`tools/rgc_lint/expr.py`).**
   Tier-1/2 started with regex string-munging for expressions/conditions; it strained on
   conditions, string-compares, and OR-chains (the predicted ceiling). Replaced with a real
   **recursive-descent parser → AST** (`Num/Str/Var/Apply/Unary/Binary`), context-free (no C,
   no array/func knowledge) so the **linter can consume the same tree**. Precedence: OR < AND
   < NOT < relational < +- < */MOD < unary < primary. `NAME(args)` parses to a generic
   `Apply` (array-vs-function resolved by the consumer). The C backend is `emit_c.to_c(node,
   ctx) -> (code, type)` with **type inference**: `=`/`<>` on string operands emit `rgc_seq()`,
   on numerics emit `==`/`!=` — the string-vs-numeric equality the regex used to hack. Migration
   verified zero-behavior-change: procgen map byte-identical to the pre-AST oracle, all three
   examples build on C64+CoCo3 and lint clean, emitted C is `-Wall -Werror` clean.
2. **Block pairing** — `FOR`↔`NEXT` and `WHILE`↔`WEND` stacks → matching C `{`/`}`.
3. **Emit layer** — `Statement` + AST → `game`-shaped `.c`.

**Why this matters (the synthesis, now real):** the linter and transpiler **share one front
end** — `tokenizer.py` (statements) + `expr.py` (expression AST). Improving the parser for the
transpiler improves the linter's diagnostics, and vice-versa. `basic.c` stays the keyword
source of truth via the drift guard; the Python front end never forks from it. *Statement-level*
walking still rides the `Statement` stream (it works); only expressions needed the AST.

## § Why the C-emit path is strategically better

- **Emitted C is a deliverable asset**, not just an internal step: hand-editable,
  inspectable, shippable. Sell it (cf. distributables plan). Don't hide the generated C.
- **Expose the intermediate files** (tokens → AST → C) for debuggability and for teaching
  users what their BASIC actually compiles to.
- **Future milestone — call C from RGC-BASIC** (FFI / inline C / `extern` decl). Natural
  here: generated C already sits beside `platform.h` and the adapters, so user-supplied C
  passes straight through the emitter. Far harder via the interpreter or the ugBASIC
  backend. Schedule after C-emit is stable.
