# RGC-BASIC → C output (cc65 / z88dk) — design notes

This document sketches how the **RGC-BASIC** front end could be extended with a **C code generator** so programs can be compiled with **cc65** (6502 targets) or **z88dk** (Z80 and others), instead of (or in addition to) interpretation.

It is **not** implemented today; it is a roadmap for a **subset compiler / transpiler** with a **portable C** intermediate step.

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
