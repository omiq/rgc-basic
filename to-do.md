# Features to add/to-do

* ~INSTR~

* Flexible DATA read
  * RESTORE [line number]

* ~Decimal ↔ hexadecimal conversion: DEC(),HEX$()~

* IF THEN ELSE END IF
  * Internally can be handled like : but this syntax is easier to read and understand

* Structured loops: DO,LOOP,WHILE,UNTIL,EXIT
  * Internally can be handled with labels and gotos but is far easier to understand

* ~Colour without pokes~
  * ~background command for setting screen colour~
  * ~colour/color for text colour~

* ~Cursor On/Off~

* PETSCII symbols
  * ~Unicode stand-ins~
  * Bitmap rendering of 320x200 pixel or 40x25 characters (SDL? Raylib?)

* Subroutines and Functions
  * Syntax sugar before actual implementation?

* Program text preprocessor
  * Replace current ad-hoc whitespace tweaks with a small lexer-like pass for keywords and operators
  * Normalize compact CBM forms while preserving semantics, e.g.:
    * `IFX<0THEN` → `IF X<0 THEN`
    * `FORI=1TO9` → `FOR I=1 TO 9`
    * `GOTO410` / `GOSUB5400` → `GOTO 410` / `GOSUB 5400`
    * `IF Q1<1ORQ1>8ORQ2<1ORQ2>8 THEN` → proper spacing around `OR` and `AND`
  * Ensure keywords are only recognized when not inside identifiers (e.g. avoid splitting `ORD(7)` or `FOR`), and never mangling string literals
  * Validate behavior against reference interpreter (`cbmbasic`) with a regression suite of tricky lines

* Include files / libraries
  * Design a simple `INCLUDE "file.bas"` or similar directive processed at load time
  * Allow splitting larger programs into multiple source files / libraries while preserving line-numbered semantics
  * Consider search paths and guarding against recursive includes

* Shebang-aware loader
  * Teach `load_program` to ignore an initial `#!...` shebang line before deciding numbered vs numberless mode
  * Allow Unix-style executable BASIC scripts with a shebang (`#!/usr/bin/env ./basic`) without triggering the "mixed numbered and numberless" error

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

