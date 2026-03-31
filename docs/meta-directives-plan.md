# Meta Directives Plan (`#`-prefixed)

**Status**: Implemented  
**Goal**: Support shebangs, includes, and in-program equivalents of command-line options, using `#` as the meta prefix.

---

## 1. Rationale

- **Parity**: Anything available as a command-line switch should be settable from within the program.
- **Shebangs**: `#!/usr/bin/env basic` at the top of a script should not cause errors.
- **Includes**: Split programs across files; useful for libraries and larger projects.
- **Unified prefix**: `#` signals "meta" (preprocessor-like, load-time) rather than executable BASIC.

---

## 2. Processing Model

All `#` directives are handled **at load time**, before the program is numbered, parsed, or run. They are never executed at runtime.

**Order of processing** (conceptual):

1. Read source file(s).
2. For each line, before mode/numbering decisions:
   - If first line and starts with `#!` → treat as shebang, skip entirely.
   - If starts with `#` (after optional whitespace) → process as directive, do not add to program.
3. For `#INCLUDE`, splice included file content into the stream at that point (see below).
4. Continue with normal load: numbering, DATA collection, label table, etc.

---

## 3. Directive Syntax

### 3.1 Shebang (special case)

- **Syntax**: First line of file, starting with `#!` (optional leading BOM/whitespace).
- **Effect**: Ignored. Does not affect numbered vs numberless mode. Does not appear in program.
- **Example**: `#!/usr/bin/env basic`

### 3.2 Include

- **Syntax**: `#INCLUDE "path"` or `#INCLUDE 'path'`
- **Effect**: Replace this "line" with the contents of the given file, as if concatenated in place.
- **Semantics**: "Pipe" semantics — the included file's text is spliced into the stream at that point. Processing continues as one logical document.
  - In **numberless mode**: included lines get synthetic numbers in sequence.
  - In **numbered mode**: included file can have its own line numbers; they merge. **Duplicate line numbers**: error (e.g. "Duplicate line number 100 in include"). **Recommendation**: use numberless mode when using includes to avoid such collisions.
- **Search path**: No env vars or PATH. Resolve relative to the current file's directory only: bare `"file"` → same dir; `"dir/file"` or `"sub/lib.bas"` → relative path.
- **Guards**: Recursive includes (A includes B includes A) must be detected and rejected (e.g. depth limit or path set).

### 3.3 Options (mirror command-line)

Each option behaves **exactly as if** the user had passed that argument on the command line. Same globals, same semantics.

| Directive | Effect | Maps to |
|-----------|--------|---------|
| `#OPTION petscii` | PETSCII mode (Unicode glyphs, colors) | `-petscii` |
| `#OPTION petscii-plain` | PETSCII, no ANSI (plain output) | `-petscii-plain` |
| `#OPTION charset upper` | Uppercase/graphics charset | `-charset upper` |
| `#OPTION charset lower` | Lowercase/uppercase charset | `-charset lower` |
| `#OPTION palette ansi` | ANSI palette | `-palette ansi` |
| `#OPTION palette c64` | C64-style 8-bit palette | `-palette c64` |
| `#OPTION gfx_title "title"` | Window title (basic-gfx) | `-gfx-title "title"` |
| `#OPTION border N [colour]` | Border padding in pixels, optional colour (basic-gfx) | `-gfx-border "N"` or `-gfx-border "N colour"` |
| `#OPTION memory c64` / `pet` / `default` | Virtual bases for `POKE`/`PEEK` (basic-gfx + canvas WASM) | `-memory c64` (basic-gfx) |
| `#OPTION screen ADDR` | Screen RAM base (decimal, `$hex`, or `0xhex`) | — |
| `#OPTION colorram ADDR` | Colour RAM base | — |
| `#OPTION charmem ADDR` | Character / UDG RAM base | — |
| `#OPTION keymatrix ADDR` | Keyboard matrix base (`PEEK` key state) | — |
| `#OPTION bitmap ADDR` | Hi-res bitmap base | — |

**Syntax**: `#OPTION name [value]`

- Case-insensitive for the keyword `OPTION` and option names.
- Values (e.g. `upper`, `lower`, `ansi`, `c64`) also case-insensitive.
- Unknown options: error (keeps things explicit) or warning+ignore (TBD).

**Order**: File options override command-line. The source file is the source of truth; `#OPTION` effectively replaces the equivalent CLI flag. Later `#OPTION` in the file overrides earlier for the same setting.

---

## 4. Include: "Pipe" Semantics

When `#INCLUDE "lib.bas"` is encountered:

1. Open `lib.bas` (relative to current file's directory).
2. Read all lines from `lib.bas`.
3. Insert those lines **in place** of the `#INCLUDE` line.
4. Continue loading as if the included content had always been there.

```
main.bas:                    Effect (conceptual stream):
10 PRINT "A"                 10 PRINT "A"
#INCLUDE "lib.bas"           100 REM helper
20 PRINT "B"                 110 DEF FNH(X)=X*2
                             20 PRINT "B"
```

In numbered mode, included lines keep their numbers; duplicates cause an error. In numberless mode, synthetic numbers continue in order. The result is a single program with merged lines.

**Recursion**: Track open files; if `#INCLUDE "foo.bas"` is seen while loading `foo.bas` (directly or indirectly), error: "Circular include: foo.bas".

---

## 5. Implementation Notes

### 5.1 Where to hook

- **load_program()** in `basic.c`: currently reads line-by-line with `fgets`. A pre-pass or integrated pass could:
  - Detect shebang on first line, skip.
  - Detect `#` lines, dispatch to option handler or include expander.
  - For includes, push current file/position onto a stack, open new file, read from it, pop when done.

### 5.2 Option application

- Options set the same globals as `basic_parse_args`: `petscii_mode`, `petscii_plain`, `petscii_no_wrap`, `petscii_lowercase_opt`, `palette_mode`, etc.
- **When**: Command-line is parsed first, then file directives during load. File options override CLI — the source file is the source of truth.

### 5.3 Include search path

- Base: directory of the file containing the `#INCLUDE`.
- No `$PATH`, no env vars, no `-I`. Bare filename → same dir; `"sub/foo.bas"` → relative to current file.

---

## 6. Resolved

- **File vs CLI**: File options override command-line.
- **Include path**: Current directory only; relative paths like `"sub/file.bas"`; no PATH/env.
- **Duplicate line numbers**: Error. Recommend numberless mode when using includes.

### Open Questions

- Should `#OPTION` support future flags (e.g. `-gfx`) or only current ones?
- Directive parsing: allow `# OPTION` (space) or strictly `#OPTION`?

---

## 7. Non-Goals (for this plan)

- `#IFDEF` / conditional compilation.
- `#DEFINE` macros.
- Runtime evaluation of directives.
