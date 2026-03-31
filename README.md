```
                                                                              
▄▄▄▄▄▄▄    ▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄       ▄▄▄▄▄▄▄     ▄▄▄▄    ▄▄▄▄▄▄▄ ▄▄▄▄▄  ▄▄▄▄▄▄▄ 
███▀▀███▄ ███▀▀▀▀▀  ███▀▀▀▀▀       ███▀▀███▄ ▄██▀▀██▄ █████▀▀▀  ███  ███▀▀▀▀▀ 
███▄▄███▀ ███       ███            ███▄▄███▀ ███  ███  ▀████▄   ███  ███      
███▀▀██▄  ███  ███▀ ███      ▀▀▀▀▀ ███  ███▄ ███▀▀███    ▀████  ███  ███      
███  ▀███ ▀██████▀  ▀███████       ████████▀ ███  ███ ███████▀ ▄███▄ ▀███████ 
                                                                              
                                                                              
                                                             
```                                                             

# RGC-BASIC

**Retro Game Coders BASIC** — modern cross-platform BASIC interpreter with classic syntax compatibility, written in C.

RGC-BASIC is *inspired by* CBM BASIC v2 as found on classic Commodore machines, extended with modern features (graphics, browser/WASM, structured syntax, and more). This means while you *can* use `GOTO`, you don't *have* to. You do you. This is a readme file, not the code police.

Unlike emulators, this is a BASIC interpreter that can already do real work: reading and writing files, user-defined functions, structured control flow, and more. In addition to the **terminal interpreter** (`basic`), there is a full **graphical interpreter** (`basic-gfx`) built with Raylib — a complete 40×25 PETSCII windowed environment with `POKE`/`PEEK` screen memory, `INKEY$`, `TI`/`TI$`, and `.seq` art viewers.

## Why Commodore BASIC?

The project started as an expansion on an original LLM-generated demo project by [David Plummer](https://github.com/davepl/pdpsrc/tree/main/bsd/basic). As I played with it, and added to it, I had fun. That's enough reason for me, and nobody is going to take your favourite toolchain away because this exists so calm down, sheesh.

Current release: **1.5.0** (2026-03-18). See `CHANGELOG.md` for the full versioned history.

## 💾 DOWNLOADS

[The latest binaries for Win/Mac/Linux are in Releases](https://github.com/omiq/rgc-basic/releases/). For bleeding-edge builds from `main`, use the [**nightly** release](https://github.com/omiq/rgc-basic/releases/tag/nightly) (built automatically every night).

Extract the files after downloading.

Each release archive includes the terminal interpreter (`basic`), the graphical interpreter (`basic-gfx`), and the `examples` folder. Run programs such as `./basic examples/trek.bas` or `./basic-gfx -petscii examples/gfx_colaburger_viewer.bas` (Windows: `basic.exe`, `basic-gfx.exe`).

![gitscreenshot1.png](https://github.com/omiq/rgc-basic/blob/main/docs/git-screenshot1.png)



---

### macOS Gatekeeper note 🔐

On recent macOS versions, downloading a binary from the internet may show a warning such as:

> “Apple could not verify `basic` is free of malware that may harm your Mac or compromise your privacy.”

Because `basic` is an unsigned open‑source binary, this is expected. To run it anyway:

1. **First attempt to open it once** (so Gatekeeper records it):
  - In Finder, locate the unpacked `basic` binary.
  - Control‑click (or right‑click) and choose **Open**.
  - When the warning dialog appears, click **Cancel**.
2. **Allow the app in System Settings**:
  - Open **System Settings → Privacy & Security**.
  - Scroll down to the **Security** section; you should see a message about `basic` being blocked.
  - Click **Open Anyway**, then confirm in the dialog.
3. After this, you should be able to run `./basic` from Terminal without further prompts.

If you prefer using Terminal only, you can also remove the quarantine attribute:

```bash
xattr -d com.apple.quarantine /path/to/basic
```

Run this once after unpacking, and macOS will stop treating the binary as “from the internet”.

---

## 💡 Features

- **Meta directives** (load-time, `#` prefix) — see `docs/meta-directives-plan.md`:
  - Shebang: `#!/usr/bin/env basic` on first line (ignored).
  - `#OPTION petscii` / `#OPTION charset lower` / `#OPTION palette c64` / `#OPTION maxstr 255` / `#OPTION columns 80` / `#OPTION nowrap` — mirror command-line options; file overrides CLI.
  - **basic-gfx / canvas WASM only — virtual memory bases for `POKE`/`PEEK`:** `#OPTION memory c64` (default layout), `#OPTION memory pet` (screen RAM at `$8000`, colour at `$9000`, charset at `$A000`, keyboard matrix still `$DC00`, bitmap at `$2000`), or `#OPTION memory default` (same as `c64`). Override individual regions with decimal or hex: `#OPTION screen $8000`, `#OPTION colorram 55296`, `#OPTION charmem 0xA000`, `#OPTION keymatrix 56320`, `#OPTION bitmap 8192`. Regions must each fit in 64K; overlapping addresses use fixed priority (text → colour → charset → keyboard → bitmap). Command-line: `-memory c64|pet|default` (basic-gfx only).
  - `#INCLUDE "path"` — splice another file at that point. Recommend numberless mode when using includes; duplicate line numbers and labels error.
- **Programs with or without line numbers**
  - Classic **line-numbered programs** loaded from a text file (`10 ...`, `20 ...`, etc.).
  - Also supports **numberless programs**: if the first non‑blank line has no leading digits, synthetic line numbers are assigned internally (you can still use labels and structured control flow).
- **Core statements**
  - `PRINT` / `?`: output expressions, with `;` (no newline) and `,` (zone/tab) separators. Default 40 columns (C64‑style); use `#OPTION columns 80` or `-columns 80` for 80‑column mode. Use `-nowrap` to disable wrapping (let the terminal handle line length).
  - `INPUT`: read numeric or string variables from standard input, with optional prompt.
  - `GET`: **non-blocking** single‑key input into a string variable (e.g. `GET K$`).
    - If a key is waiting, `K$` becomes a 1‑character string.
    - If no key is waiting, `K$` becomes `""`.
    - Enter/Return is returned as `CHR$(13)` so `ASC(K$)=13` works for “press Enter” checks.
  - `LET` (optional): assignment; you can also assign with `A=1` without `LET`.
  - `IF ... THEN` / `IF ... ELSE ... END IF`: conditional execution. Inline `IF X THEN 100` or `IF X THEN PRINT "Y"`; multi-line blocks with `IF X THEN` … `ELSE` … `END IF`. Supports nested blocks.
  - `WHILE` … `WEND`: pre-test loops. `WHILE X < 5` … `WEND`; supports nested WHILE/WEND.
  - `DO` … `LOOP [UNTIL cond]`: post-test / infinite loops. `DO` … `LOOP` repeats until `EXIT`; `DO` … `LOOP UNTIL X>5` exits when the condition is true. `EXIT` leaves the innermost DO loop. Nested DO/LOOP supported.
  - `GOTO`: jump to a given line number **or label** (e.g. `GOTO 100` or `GOTO GAMELOOP`).
  - `GOSUB` / `RETURN`: subroutines with a fixed-depth stack; targets may be line numbers or labels.
  - `ON expr GOTO` / `ON expr GOSUB`: multi-branch jumps; e.g. `ON N GOTO 100,200,300` or `ON K GOSUB 500,600`.
  - `FOR` / `NEXT`: numeric loops, including `STEP` with positive or negative increments.
  - `DIM`: declare 1‑D or multi‑dimensional numeric or string arrays (e.g. `DIM A(10)`, `DIM B(2,3)`).
  - `REM` and `'`: comments to end of line.
  - `END` / `STOP`: terminate program execution.
  - `READ` / `DATA`: load numeric and string literals from `DATA` statements into variables. `RESTORE` resets the DATA pointer so the next `READ` uses the first value again (C64-style). `RESTORE [line]` resets to the first DATA at or after the given line number.
  - `DEF FN`: define simple user functions, e.g. `DEF FNY(X) = SIN(X)`.
  - **User-defined FUNCTIONS** (implemented): multi-line, multi-parameter functions:
    - `FUNCTION name [(param1, param2, ...)]` … `RETURN [expr]` … `END FUNCTION`.
    - Call with brackets always: `result = add(3, 5)` or `sayhi()` for side effects.
    - `RETURN expr` returns a value; `RETURN` or `END FUNCTION` with no prior RETURN yields 0/`""` in expression context.
    - Parameters are local; recursion supported. See `docs/user-functions-plan.md` for the design.
  - `POKE`: accepted as a no‑op (for compatibility with old listings; it does not touch real memory).
  - `SORT arr [, mode]`: in-place sort of a 1‑D array. `mode` is `1` or `"asc"` (default) for ascending, `-1` or `"desc"` for descending. Works on numeric and string arrays.
  - `SPLIT str$, delim$ INTO arr$`: split a string by delimiter into a pre-dimmed 1‑D string array.
  - `JOIN arr$, delim$ INTO result$ [, count]`: join array elements with a delimiter into a string. Uses the count from the last `SPLIT` if `count` is omitted.
  - `LOAD "path" INTO addr [, length]` / `LOAD @label INTO addr [, length]`: (basic-gfx only) load raw bytes from a file or from a `DATA` block at a label into virtual memory. Terminal build reports an error.
  - `MEMSET addr, len, val` / `MEMCPY dest, src, len`: (basic-gfx only) fill or copy bytes in virtual memory. Terminal build reports an error.
  - `CLR`: resets all variables to 0/empty, clears GOSUB/FOR stacks and DATA pointer; DEF FN definitions are kept.
  - **File I/O (CBM-style)**:
    - `OPEN lfn, device, secondary, "filename"` — open a file (device 1 = disk/file; secondary 0 = read, 1 = write, 2 = append). Filename is a path in the current directory.
    - `PRINT# lfn, expr [,|; expr ...]` — write to the open file (like `PRINT` to file).
    - `INPUT# lfn, var [, var ...]` — read from the open file into variables (one token per variable; comma/newline separated).
    - `GET# lfn, stringvar` — read one character from the file into a string variable.
    - `CLOSE [lfn [, lfn ...]]` — close file(s); `CLOSE` with no arguments closes all.
    - `ST` — system variable set after `INPUT#`/`GET#`: 0 = success, 64 = end of file, 1 = error / file not open. Use e.g. `IF ST <> 0 THEN GOTO done`.
- **Variables**
  - **Numeric variables**: `A`, `B1`, `SALE`, `SAFE`, `PLAYERSCORE`, `my_var`, etc. Full variable names up to 31 characters are significant (e.g. `SALE` and `SAFE` are distinct). Underscores (`_`) are allowed.
  - **String variables**: names ending in `$`, e.g. `A$`, `NAME$`.
  - **Reserved words** (e.g. `IF`, `FOR`, `PRINT`) cannot be used as variable names. Labels may match keywords (e.g. `CLR:`).
  - **Arrays**: 1‑D or multi‑dimensional, e.g. `A(10)`, `A$(20)`, `C(2,3)`. Index is 0‑based internally; `DIM A(10)` allows indices `0..10`; `DIM C(2,3)` gives a 3×4 matrix.
- **Intrinsic functions**
  - **Math**: `SIN`, `COS`, `TAN`, `ABS`, `INT`, `SQR`, `SGN`, `EXP`, `LOG`, `RND`.
  - **Strings**:
    - `LEN`, `VAL`, `STR$`, `CHR$`, `ASC`, `INSTR`.
    - `INSTR(source$, search$ [, start])` – 1‑based index of `search$` in `source$`, or `0` if not found. Optional `start` (1‑based) begins the search from that position.
    - `REPLACE(str$, find$, repl$)` – replace all occurrences of `find$` with `repl$`.
    - `TRIM$(s$)`, `LTRIM$(s$)`, `RTRIM$(s$)` – strip leading, trailing, or both whitespace.
    - `FIELD$(str$, delim$, n)` – extract the *n*th field (1‑based) from a delimited string (awk‑like).
    - `UCASE$`, `LCASE$`: convert string to upper or lower case (ASCII).
    - `MID$`, `LEFT$`, `RIGHT$` with C64‑style semantics:
      - `MID$(S$, start)` or `MID$(S$, start, len)` (1‑based `start`).
      - `LEFT$(S$, n)` – first `n` characters.
      - `RIGHT$(S$, n)` – last `n` characters.
  - **Arrays**:
    - `INDEXOF(arr, value)` / `LASTINDEXOF(arr, value)` – 1‑based index of first/last element equal to `value`, or `0` if not found. Works on numeric and string arrays.
  - **JSON**:
    - `JSON$(json$, path$)` – path-based extraction from a JSON string. Returns the value at `path` as a string. Path format: `"key"`, `"key[0]"`, `"key.subkey"`, etc. Use `VAL(JSON$(j$, "count"))` for numeric values.
  - **Environment & platform**:
    - `ENV$(name$)` – returns the value of environment variable `name$`, or `""` if not set.
    - `PLATFORM$()` – returns `"linux-terminal"`, `"linux-gfx"`, `"windows-terminal"`, `"windows-gfx"`, `"mac-terminal"`, or `"mac-gfx"` depending on OS and build.
  - **Runtime evaluation**:
    - `EVAL(expr$)` – evaluates the string `expr$` as a BASIC expression and returns the result (numeric or string). Useful for interactive testing and dynamic expressions.
  - **Formatting**: `TAB` and `SPC` for horizontal positioning in `PRINT`.
  - **Numeric/string conversion**:
    - `DEC(s$)` – parse a hexadecimal string to a numeric value (e.g. `DEC("FF")` = 255, invalid strings yield 0).
    - `HEX$(n)` – format a number as an uppercase hexadecimal string (no `$` prefix), using the integer part of `n`.
  - **Command-line arguments and shell** (for scripting):
    - `ARGC()` — returns the number of arguments passed after the script path (e.g. `./basic script.bas a b` → `ARGC()` = 2). Use `ARGC()` with parentheses.
    - `ARG$(n)` — returns the *n*th argument as a string. `ARG$(0)` is the script path; `ARG$(1)` … `ARG$(ARGC())` are the arguments. Out-of-range returns `""`.
    - `SYSTEM(cmd$)`** — runs a shell command (e.g. `SYSTEM("ls -l")`), waits for it to finish, and returns its exit status (0 = success).
    - `EXEC$(cmd$)` — runs a shell command and returns its standard output as a string (up to 255 characters; trailing newline trimmed). Use for scripting (e.g. `U$ = EXEC$("whoami")`).

### Additional/Non-Standard BASIC Commands

- `SLEEP`: pause execution for a number of 60 Hz “ticks” (e.g., `SLEEP 60` ≈ 1 second).
- `LOCATE` and `TEXTAT`: screen cursor positioning and absolute text placement (see below).
- `CURSOR ON` / `CURSOR OFF`: show or hide the terminal cursor using ANSI escape codes (`ESC[?25h` / `ESC[?25l`).
- `COLOR n` / `COLOUR n`: set the text **foreground** colour using a C64-style palette index `0–15`, mapped to ANSI SGR colours (approximate CBM palette).
- `BACKGROUND n`: set the text **background** colour using the same C64-style palette index `0–15`, mapped to ANSI background SGR codes (e.g. 0=black, 1=white, 2=red, 3=cyan, etc.).

### Tokenised PETSCII shortcuts inside strings

- Inline `{TOKENS}` (see `docs/c64-color-codes.md` for full reference):
  - Within double-quoted strings, the interpreter recognises `{...}` patterns and expands them to `CHR$()` calls **at load time**.
  - Numeric: `{147}`, `{$93}`, `{0x93}`, `{%10010011}` (decimal, hex, binary).
  - Colors: `{RED}`, `{CYN}`, `{BLACK}`, `{LIGHTBLUE}`, etc. (full and abbrev).
  - Screen: `{HOME}`, `{CLR}`, `{DEL}`, `{INS}`, `{CURSOR UP}`, `{CRSR RIGHT}`, etc.
  - Reverse: `{RVS}`, `{RVS ON}`, `{RVS OFF}`, `{REVERSE OFF}`.
  - Function keys: `{F1}` … `{F8}`. Symbol: `{PI}`.
  - **ANSI reset** (terminal): `{RESET}` / `{DEFAULT}` — `ESC [ 0 m` to reset to default colors.
  - This lets you write readable code such as:

```basic
PRINT "HELLO {RED}WORLD{WHITE}"
PRINT "{CLR}READY."
PRINT "MOVE {DOWN}{DOWN}{RIGHT} HERE"
```

- **What it does**:
  - Each `{TOKEN}` inside a string is replaced as if you had written `";CHR$(N);"` at that point in the source, so all existing PETSCII/ANSI mappings for `CHR$` apply unchanged.
  - Tokens can be:
    - **Numeric**: e.g. `{147}` → `CHR$(147)`.
    - **Named** PETSCII codes from the built-in table, including:
      - Colors: `WHITE`, `RED`, `CYAN`, `PURPLE`, `GREEN`, `BLUE`, `YELLOW`, `ORANGE`, `BROWN`, `PINK`, `GRAY1`/`GREY1`, `GRAY2`/`GREY2`, `GRAY3`/`GREY3`, `LIGHTGREEN`/`LIGHT GREEN`, `LIGHTBLUE`/`LIGHT BLUE`, `BLACK`.
      - Screen/control keys: `HOME`, `DOWN`, `UP`, `LEFT`, `RIGHT`, `DEL`/`DELETE`, `INS`/`INSERT`, `CLR`/`CLEAR`.
      - Reverse video: `RVS`, `REVERSE ON`, `RVS OFF`, `REVERSE OFF`.
- **Behaviour notes**:
  - Token expansion is **purely a source transform**; once loaded, the program runs exactly as if you had typed the equivalent `CHR$()` expressions yourself.
  - Tokens are only recognised **inside quoted strings**; everything else in your BASIC code is left untouched.

### Screen coordinates and cursor positioning

- **Coordinate system**:
  - `LOCATE col, row` and `TEXTAT col, row, text` both use **0‑based** screen coordinates, where `0,0` is the top‑left corner.
  - Internally these are mapped to ANSI escape sequences as `ESC[row+1;col+1H`.
- `LOCATE`:
  - Moves the cursor without printing: e.g. `LOCATE 10,5` positions the cursor at column 10, row 5 before the next `PRINT`.
- `TEXTAT`:
  - `TEXTAT x, y, text` moves the cursor to `(x, y)` and writes `text` directly at that absolute position.
  - `text` is any string expression, for example: `TEXTAT 0, 0, "SCORE: " + STR$(S)`.
- **Keeping final text visible**:
  - Terminals often print the shell prompt immediately after your program exits; if your last output is on the bottom row, an implicit newline or prompt can scroll it off‑screen.
  - To make sure your final UI remains visible, **explicitly position the cursor after your last `TEXTAT`/`LOCATE` output**, for example:

```basic
LOCATE 0, 22
PRINT "PRESS ANY KEY TO CONTINUE";
```

- This ensures the cursor (and thus any following prompt) appears where you expect, rather than accidentally pushing your last line out of view.

## 🎛️ Usage

The interpreter runs a BASIC source file that contains **line‑numbered** statements:

```text
10 PRINT "HELLO, WORLD!"
20 END
```

Run the interpreter and pass the path to your BASIC program:

```bash
./basic hello.bas        # Linux / macOS / WSL
basic.exe hello.bas      # Windows
```

#### Command-line options

- `-petscii` / `--petscii`: enable PETSCII/ANSI mode so that certain `CHR$` control codes
(cursor movement, clear screen, colors, etc.) are translated to ANSI escape sequences.
Printable and graphics PETSCII codes are mapped to Unicode (e.g. £ ↑ ←, box-drawing, card suits).
- `-petscii-plain` / `--petscii-plain`: PETSCII mode **without** ANSI: control and color codes
output nothing (invisible, like on a real C64), and only printable/graphics bytes produce
visible characters. Use this when you need strict one-character-per-column alignment (e.g.
viewing .seq files or pasting output into a fixed-width editor).
- `-charset upper|lower`: choose the PETSCII **character set** used for rendering letters in `-petscii` mode:
  - `upper` (default): C64 **uppercase/graphics** character set.
  - `lower`: C64 **lowercase/uppercase** character set (useful for `.seq` art that uses lowercase letters).
- `-palette ansi|c64`: choose how PETSCII colors are mapped (only in `-petscii` mode):
  - `ansi` (default): map colors to standard 16-color ANSI SGR codes.
  - `c64` or `c64-8bit`: use 8‑bit (`38;5;N`) color indices chosen to approximate
  the classic C64 palette. This is most consistent on terminals that support 256 colors.
- `-maxstr N`: maximum string length (1–4096); default 4096. Use `-maxstr 255` for C64 compatibility. Can also be set with `#OPTION maxstr 255`. Affects string literals, concatenation, `STRING$`, and related operations.
- `-columns N`: print width in columns (1–255); default 40. Use `-columns 80` for 80‑column mode. Comma zones scale (10 chars at 40 cols, 20 at 80 cols). Can also be set with `#OPTION columns 80`.
- `-nowrap`: do not insert newlines at column width; let the terminal handle wrapping. Useful for wide output or paste-into-editor. Can also be set with `#OPTION nowrap`.

You can also enable a **PETSCII/ANSI mode** that understands common C64 control codes inside strings and `CHR$` output:

```bash
./basic -petscii hello.bas
```

In `-petscii` mode, `CHR$` behaves in a C64-like way: control and color codes are mapped to ANSI escapes, and **printable/graphics PETSCII codes** (block graphics, arrows, card suits, etc.) are mapped to Unicode so they display sensibly in the terminal.

- **Screen control**
  - `CHR$(147)`: clear screen and home cursor (maps to `ESC[2J ESC[H]`).
  - `CHR$(17)`: cursor down (`ESC[B]`).
  - `CHR$(145)`: cursor up (`ESC[A]`).
  - `CHR$(29)`: cursor right (`ESC[C]`).
  - `CHR$(157)`: cursor left (`ESC[D]`).
  - `CHR$(18)`: reverse video on (`ESC[7m]`).
  - `CHR$(146)`: reverse video off (`ESC[27m]`).
  - `CHR$(14)`: switch to **lowercase/uppercase** character set (C64 “lowercase mode”).
  - `CHR$(142)`: switch to **uppercase/graphics** character set (C64 “uppercase mode”).
- **Basic text colors** (ANSI approximations of C64 colors)

  | C64 index (`COLOR`/`BACKGROUND`) | PETSCII `CHR$()` | Token(s) you can use in `{TOKENS}` | Approximate colour |
  | -------------------------------- | ---------------- | ---------------------------------- | ------------------ |
  | 0                                | `CHR$(144)`      | `BLACK`                            | black              |
  | 1                                | `CHR$(5)`        | `WHITE`                            | white              |
  | 2                                | `CHR$(28)`       | `RED`                              | red                |
  | 3                                | `CHR$(159)`      | `CYAN`                             | cyan               |
  | 4                                | `CHR$(156)`      | `PURPLE`                           | purple             |
  | 5                                | `CHR$(30)`       | `GREEN`                            | green              |
  | 6                                | `CHR$(31)`       | `BLUE`                             | blue               |
  | 7                                | `CHR$(158)`      | `YELLOW`                           | yellow             |
  | 8                                | `CHR$(129)`      | `ORANGE`                           | orange             |
  | 9                                | `CHR$(149)`      | `BROWN`                            | brown              |
  | 10                               | `CHR$(150)`      | `PINK` / light red                 | light red          |
  | 11                               | `CHR$(151)`      | `GRAY1` / `GREY1`                  | dark gray          |
  | 12                               | `CHR$(152)`      | `GRAY2` / `GREY2`                  | medium gray        |
  | 13                               | `CHR$(153)`      | `LIGHTGREEN` / `LIGHT GREEN`       | light green        |
  | 14                               | `CHR$(154)`      | `LIGHTBLUE` / `LIGHT BLUE`         | light blue         |
  | 15                               | `CHR$(155)`      | `GRAY3` / `GREY3`                  | light gray         |


If you do not pass a file name, the interpreter will print usage information:

```text
Usage: basic [-petscii] [-petscii-plain] [-charset upper|lower] [-palette ansi|c64] [-maxstr N] [-columns N] [-nowrap] <program.bas>
```

### Shell scripting: standard I/O and arguments

You can use the interpreter for shell-script style tasks:

- **Standard input/output**  
`INPUT` reads from standard input (one line or token at a time). `PRINT` writes to standard output. So you can pipe data in and out:
  - `echo 42 | ./basic program.bas`
  - `./basic program.bas > out.txt`
  Errors and usage go to **stderr**; only program output goes to stdout when you redirect.
- **Runtime errors**  
  When execution stops, the interpreter prints the error on **stderr**, with the **BASIC line number** and source when possible, and often a second line starting with **`Hint:`** with a short fix suggestion (wrong types, missing **`THEN`**, bad **`GOTO`** targets, **`#INCLUDE`** syntax, and many builtins). In the browser/WASM build, the same text appears in the output panel.
- **Load-time errors**  
  Problems while reading the source file (unknown **`#OPTION`**, **`#INCLUDE`** path issues, line too long, duplicate line number in an include, mixed numbered and numberless lines, etc.) are reported on **stderr** before the program runs; many of these messages also include a **`Hint:`** line.
- **Command-line arguments**  
Anything after the script path is available to the program:
  - `./basic script.bas first second`
  - In the script: `ARG$(0)` = script path, `ARG$(1)` = `"first"`, `ARG$(2)` = `"second"`, `ARGC()` = 2.
- **Running shell commands**  
`SYSTEM("command")` runs the command and returns its exit code. `EXEC$("command")` runs the command and returns its stdout as a string (e.g. `PRINT EXEC$("date")`).  
Example: `examples/scripting.bas` demonstrates `ARGC()`, `ARG$()`, `SYSTEM()`, and `EXEC$()`.
- **Interactive expression testing**  
`EVAL(expr$)` evaluates a string as a BASIC expression. Use it to try functions and operators without writing a full program: e.g. `PRINT EVAL("2+3")`, or build expressions in variables (`E$ = "SIN(3.14)" : PRINT EVAL(E$)`) and pass them to `EVAL`. Use `CHR$(34)` for quotes inside EVAL strings.

### Source normalization (compact CBM style)

Program text is normalized at load time so **compact CBM BASIC** without spaces around keywords is accepted. For example: `IFX<0THEN`, `FORI=1TO9`, `GOTO410`, `GOSUB5400`, and similar forms are rewritten with spaces so the parser recognises `IF`/`THEN`, `FOR`/`TO`/`NEXT`, `GOTO`, and `GOSUB`. This helps run listings that were saved with minimal whitespace.

---

### 🎨 Graphical interpreter (basic-gfx)

Releases include **basic-gfx** — a full graphical version of the interpreter built with Raylib. It provides a 40×25 (or 80×25 with `-columns 80`) PETSCII windowed display with `POKE`/`PEEK` screen memory, `INKEY$`, `TI`/`TI$`, `.seq` art viewers, and full PETSCII symbols:

![Cola Burger](https://github.com/omiq/rgc-basic/blob/main/docs/git-screenshot2.png)



(building requires Raylib to be installed - build the graphics target via `make basic-gfx)`

- `./basic-gfx examples/gfx_poke_demo.bas`
- `./basic-gfx examples/gfx_border_demo.bas` — border padding with colour (`#OPTION border 32 cyan`)
- `./basic-gfx examples/gfx_charset_demo.bas`
- `./basic-gfx examples/gfx_key_demo.bas`
- `./basic-gfx -petscii examples/gfx_text_demo.bas`
- `./basic-gfx -petscii examples/gfx_inkey_demo.bas`
- `./basic-gfx -petscii examples/gfx_jiffy_game_demo.bas`
- `./basic-gfx -petscii -charset lower examples/gfx_colaburger_viewer.bas` — displays `.seq` art with correct PETSCII rendering (lowercase charset for “Welcome”, “Press”, etc.).
- `./basic-gfx examples/gfx_game_shell.bas` — mini game: `DATA` tile map + `POKE` walls/floor/goal, **PNG** player/enemy (`player.png`, `enemy.png`), HUD strip (`hud_panel.png`), `INKEY$()` loop (WASD). See also `examples/dungeon.bas` for a larger PETSCII/POKE map style demo.

**Hires bitmap (basic-gfx)**:

- `SCREEN 1` — 320×200 1bpp display; `SCREEN 0` — back to 40×25 text. `COLOR` / `BACKGROUND` set pen and paper in bitmap mode.
- `PSET x,y` / `PRESET x,y` — set/clear one pixel (coordinates clipped to the bitmap).
- `LINE x1,y1 TO x2,y2` — Bresenham line (same clipping).
- Example: `./basic-gfx examples/gfx_bitmap_demo.bas`

**Keyboard polling (basic-gfx)**:

- BASIC can poll a simple key-down map via `PEEK(56320 + code)` where 56320 is 0xDC00.
- Supported codes include ASCII `A`–`Z`, `0`–`9`, Space (32), Enter (13), Esc (27), and C64 cursor codes Up (145), Down (17), Left (157), Right (29).

**INPUT (basic-gfx)**:

- `INPUT` and `INPUT "prompt"; var` read from the raylib window key queue, not the terminal. The prompt and your typing appear in the 40×25 window. Backspace works. Press Enter to submit.

**INKEY$() (basic-gfx)**:

- `INKEY$()` is **non-blocking**: it returns a 1-character string for the next queued keypress, or `""` if none.
- This is driven by the raylib host; it is currently available in `basic-gfx` (gfx build) and returns `""` in the terminal build.
- Example: `./basic-gfx -petscii examples/gfx_inkey_demo.bas`

**TI / TI$ (basic-gfx)**:

- `TI` is a **60 Hz “jiffy” counter** (like C64 BASIC), incremented by the gfx host each frame and wrapping every 24 hours (24*60*60*60 = 5184000).
- `TI$` is a string formatted as `HHMMSS`.
- Terminal build: currently not driven by a host tick source (use `SLEEP` or your OS clock instead).

**SCREENCODES ON|OFF (basic-gfx)**:

- In gfx builds, `SCREENCODES ON` makes `PRINT` treat bytes as **PETSCII** from `.seq` streams; they are converted to C64 screen codes for display (same semantics as `CHR$`/terminal PETSCII).
- This is required for `.seq` art viewers such as `examples/gfx_colaburger_viewer.bas`.
- Use `SCREENCODES OFF` to restore the default (ASCII strings like `PRINT "HELLO"` map naturally).
- The window closes automatically when the program reaches `END`.

**PNG sprites / HUD overlay (basic-gfx)**:

- `LOADSPRITE slot, "file.png"` queues loading a PNG from disk. Paths are relative to the **`.bas` file’s directory** (or absolute). Only `.png` is supported here; use `LOAD "bin" INTO …` for raw bytes.
- **Tile sheet / tilemap:** `LOADSPRITE slot, "tiles.png", tw, th` treats the image as a grid of **tw×th** pixels per tile (row-major, left-to-right). Use **`DRAWSPRITETILE slot, x, y, tile_index [, z]`** with **1-based** `tile_index` (first tile = 1). **`SPRITETILES(slot)`** returns how many tiles are in the sheet. **`SPRITEW`/`SPRITEH`** return one tile’s size when a tilemap is loaded. **`DRAWSPRITE`** with **`sx, sy, sw, sh`** still works for arbitrary crops.
- **Gamepad (native basic-gfx only):** **`JOY(port, button)`** returns **1** if pressed, else **0** (Raylib `GamepadButton`: **1–15** for DPAD/face/triggers; **0** is unknown). **`JOYSTICK`** is an alias for **`JOY`**. **`JOYAXIS(port, axis)`** returns stick/trigger movement scaled to about **-1000..1000** (axes **0–5**: left X/Y, right X/Y, left trigger, right trigger). Port **0** is the first controller. Browser/canvas WASM returns **0** (no gamepad API wired yet). Example: `./basic-gfx examples/gfx_joy_demo.bas`
- `UNLOADSPRITE slot` frees that slot’s texture and clears its draw state so you can `LOADSPRITE` again (e.g. swap art or reclaim memory). No-op if the slot was empty.
- `DRAWSPRITE slot, x, y [, z [, sx, sy [, sw, sh ]]]` sets the **persistent** pose for that slot: the same image is drawn **every frame** until you call `DRAWSPRITE` again for that slot or the program exits (textures are freed when the window closes). **`x`, `y`** are **pixel** coordinates on the 320×200 framebuffer (not character rows): row *r* starts at **`y = r × 8`**. **`z`**: larger values paint **on top** (e.g. text/bitmap at 0, HUD at 200). Omit **`sx, sy`** to use the top-left of the image; omit **`sw, sh`** (or use ≤0) to use the rest of the texture from `(sx,sy)`. **Alpha** in the PNG is respected (transparency over text or bitmap).
- `SPRITEVISIBLE slot, 0|1` hides or shows a loaded sprite without unloading.
- `SPRITEW(slot)` / `SPRITEH(slot)` return pixel width/height after load (0 if not loaded yet).
- `SPRITECOLLIDE(a, b)` returns **1** if the axis-aligned bounding boxes of two visible, drawn sprites overlap, else **0** (empty slots or hidden sprites never collide).
- Example: `./basic-gfx -petscii examples/gfx_sprite_hud_demo.bas`
- **Game shell** (`examples/gfx_game_shell.bas`): tile map from `DATA` with `POKE` (walls/floor/goal), **8×8 PNG** player (`player.png`) and enemy (`enemy.png`) via `DRAWSPRITE`, `INKEY$()` loop, HUD strip (`hud_panel.png`). Run: `./basic-gfx examples/gfx_game_shell.bas`

**Window title (basic-gfx)**:

- Set the window title via `#OPTION gfx_title "My Game"` or the CLI `-gfx-title "My Game"`. Default is `RGC-BASIC GFX`.

**Border padding (basic-gfx)**:

- Add padding around the graphical area for better legibility: `#OPTION border 24` or `-gfx-border 24`. The value is pixels on each side; the screen is centered in the window. Optionally specify a colour: `#OPTION border 10 cyan` or `-gfx-border "10 cyan"` (uses background colour if omitted). Colour can be a name (black, white, red, cyan, purple, green, blue, yellow, etc.) or palette index 0–15.

---

### Included example programs

The `examples` folder (included in release archives) contains:

- `dartmouth.bas`: classic Dartmouth BASIC tutorial; exercises `PRINT`, `INPUT`, `IF`, `FOR/NEXT`, `DEF FN`, `READ`/`DATA`, and more.
- `trek.bas`: Star Trek–style game; exercises `GET`, `ON GOTO`/`GOSUB`, multi-dimensional arrays, and PETSCII-style output.
- `chr.bas`: PETSCII/ANSI color and control-code test (run with `-petscii`).
- `examples/testdef.bas`, `tests/read_data.bas`: small regressions for `DEF FN` and `READ`/`DATA`.
- `test_dim2d.bas`, `test_get.bas`: multi-dimensional arrays and `GET` Enter handling.
- `tests/fileio.bas`, `tests/fileeof.bas`, `tests/test_get_hash.bas`: file I/O regression tests.
- `examples/fileio_basics.bas`: write and read a file (OPEN, PRINT#, INPUT#, CLOSE) with step-by-step comments.
- `examples/fileio_loop.bas`: read until end of file using the ST status variable (ST=0/64/1).
- `examples/fileio_get.bas`: read one character at a time with GET#.
- `examples/c64_control_codes_demo.bas`: expanded demo of `{TOKEN}` brace substitutions (colors, screen controls, reverse video, `{RESET}`). Run: `./basic -petscii examples/c64_control_codes_demo.bas`.
- `examples/dungeon.bas`: larger PETSCII dungeon-style map with `POKE`/screen RAM and custom charset data (terminal or `basic-gfx` with `-petscii`).
- `examples/gfx_game_shell.bas`: **basic-gfx** tutorial game — tile `DATA`, `POKE` map, `LOADSPRITE`/`DRAWSPRITE` for 8×8 PNG actors (`player.png`, `enemy.png`) and HUD (`hud_panel.png`), `INKEY$()` + enemy chase. Run: `./basic-gfx examples/gfx_game_shell.bas`.
- `examples/gfx_sprite_hud_demo.bas`: minimal **DRAWSPRITE** over PETSCII (semi-transparent `hud_panel.png`); comments explain pixel vs text-row coordinates.
- `examples/gfx_canvas_demo.bas` + `examples/gfx_canvas_demo.png`: small **PETSCII + PNG sprite** sample for **basic-gfx** or **`web/canvas.html`** (upload the PNG to the virtual filesystem, or use `web/gfx_canvas_demo.png` when serving `web/`).
- `examples/colaburger_viewer.bas`, `examples/gfx_colaburger_viewer.bas`, and `examples/colaburger.seq`: PETSCII .seq file viewer.
  - **.seq files** are sequential dumps of PETSCII screen codes (e.g. from BBS logs or PETSCII art).
  - The terminal viewer reads the file byte-by-byte with `GET#`, prints each byte via `CHR$`, and wraps after
  **40 visible columns** (only printable/graphics bytes advance the cursor; control/color codes do not).
  - **Terminal**: run with `-petscii-plain` so control and color codes output nothing and alignment matches a real
  C64 screen:  
  `./basic -petscii-plain examples/colaburger_viewer.bas`  
  - **Graphics** (`basic-gfx`): run with `-petscii -charset lower` for full PETSCII rendering in a raylib window:  
  `./basic-gfx -petscii -charset lower examples/gfx_colaburger_viewer.bas`  
  - With `-petscii` you get ANSI colors and cursor codes; with `-petscii-plain` you get
  strict character alignment and no escape sequences, ideal for art and fixed-width paste.
- `examples/scripting.bas`: shell-scripting style — command-line arguments (`ARGC()`, `ARG$(0)` … `ARG$(n)`), running commands (`SYSTEM("date")`, `EXEC$("whoami")`). Run: `./basic examples/scripting.bas [name]`.
- **String & array utilities** (in `tests/`): `field_test.bas`, `sort_test.bas`, `split_join_test.bas`, `indexof_test.bas`, `json_test.bas`, `eval_test.bas`, `env_platform_test.bas` — demos of `FIELD$`, `SORT`, `SPLIT`, `JOIN`, `INDEXOF`, `LASTINDEXOF`, `JSON$`, `EVAL`, `ENV$`, `PLATFORM$`.
- **Tutorial (FUNCTIONS, #INCLUDE, WHILE, IF ELSE END IF)**:
  - `examples/tutorial_functions.bas` — non-interactive demo of user-defined functions, `#INCLUDE`, `WHILE` … `WEND`, and `IF` … `ELSE` … `END IF`. Run: `./basic examples/tutorial_functions.bas`.
  - `examples/tutorial_lib.bas` — library included by the tutorial (`is_prime`, `gcd`, `factorial`, `greet`).
  - `examples/tutorial_menu.bas` — interactive menu using the library. Run: `./basic examples/tutorial_menu.bas`.
- `guess.bas`, `adventure.bas`, `printx.bas`, and others for various features.

### Notes on the BASIC dialect

- **Line numbers are required**. Any line without a leading integer line number will be rejected when loading.
- **Statement separator**: use `:` to place multiple statements on one line:

```text
10 A = 1 : B = 2 : PRINT A+B
```

- **Comments**:
  - `REM comment text`
  - `' comment text`
- **Conditionals**:
  - Full relational operators: `<`, `>`, `=`, `<=`, `>=`, `<>`.
  - **Arithmetic**: `+`, `-`, `*`, `/`, `^` (exponentiation), `MOD` (modulo, floored).
  - **Bitwise**: `<<`, `>>` (shift), `AND`, `OR`, `XOR` (operate on integer parts of numbers).
  - String and numeric comparisons are both supported.
  - You may `THEN` jump to a line number (`IF A>10 THEN 100`) or execute inline statements after `THEN`.
- **Random numbers**:
  - `RND(X)` behaves like classic BASIC; a negative argument reseeds the generator.

This README describes the current feature set of the interpreter as implemented in `basic.c` and is subject to change without notice.

**Future / tooling (not implemented):** a possible **BASIC → C** transpiler for **cc65** / **z88dk** is outlined in [`docs/basic-to-c-transpiler-plan.md`](docs/basic-to-c-transpiler-plan.md), including which language features should be **excluded** from a first version.

---

## 🛠️ Building from Source

You can either use the provided `Makefile` (recommended) or compile manually.

### Requirements

- A C compiler with C99 (or newer) support:
  - Linux / WSL: `gcc` or `clang`
  - macOS: Xcode Command Line Tools (`clang`)
  - Windows:
    - MSVC (Visual Studio / Build Tools), or
    - MinGW‑w64 (`gcc`)
- **Optional (for raylib-based graphics builds)**:
  - **Linux / WSL**: install the raylib development package so headers and `pkg-config` metadata are available, for example:
    - Debian/Ubuntu (if available): `sudo apt-get install -y libraylib-dev`
    - If your distro does not provide `libraylib-dev`, build and install raylib from source (summary):
      - Install deps: `sudo apt-get install -y build-essential cmake git pkg-config libasound2-dev libx11-dev libxrandr-dev libxi-dev libxinerama-dev libxcursor-dev libgl1-mesa-dev libglu1-mesa-dev`
      - Build/install: `git clone https://github.com/raysan5/raylib.git && cd raylib && cmake -B build -DBUILD_SHARED_LIBS=ON && cmake --build build --config Release && sudo cmake --install build`
      - If you installed to `/usr/local/lib`, you may need: `echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/raylib.conf && sudo ldconfig`
  - **macOS** (Homebrew): `brew install raylib`
  - **Windows (MinGW)**: `basic-gfx` is built with static winpthread so it does not require `libwinpthread-1.dll`. The nightly and release builds bundle `libraylib.dll` and `glfw3.dll` with `basic-gfx.exe`. If you build locally, copy both DLLs from your MinGW `bin` folder (e.g. `C:\msys64\mingw64\bin\`) into the same directory as `basic-gfx.exe`.
  - **Linux (downloads)**: Pre-built `basic-gfx` needs `libraylib.so` matching the build (e.g. `libraylib.so.600`). If you see "cannot open shared object file", install raylib from your distro (`libraylib-dev` or equivalent) or build from source with `make basic-gfx`.
- **Optional (for browser/WASM build)**:
  - [Emscripten](https://emscripten.org/) (`emcc`) via **[emsdk](https://emscripten.org/docs/getting_started/downloads.html)** (recommended: `./emsdk install latest && ./emsdk activate latest`, then `source emsdk_env.sh` before `make basic-wasm`). Produces `web/basic.js` and `web/basic.wasm` for running the interpreter in the browser.
  - **Avoid** `apt install emscripten` on Debian/Ubuntu for this project: distro packages are often **years behind** upstream (different `EM_ASM` / Asyncify behaviour than current emsdk). CI and production deploys use **emsdk** so local builds match what users run. After upgrading emsdk, run `make clean && make basic-wasm basic-wasm-canvas` and redeploy **both** `.js` and `.wasm` together (see `web/canvas.html` cache-bust query).

#### Using `make` (recommended)

From the project root:

```bash
make
```

The Makefile will detect your platform (Linux, macOS, or Windows via MinGW/Cygwin) and produce the appropriate native binary:

- **Linux / WSL / macOS**: `basic`
- **Windows (MinGW / Cygwin)**: `basic.exe`

To clean the build:

```bash
make clean
```

**Graphics build** (`basic-gfx`):

```bash
make basic-gfx
```

**Browser/WASM build** (requires Emscripten):

```bash
make basic-wasm
# Optional: MODULARIZE terminal build for embedding multiple interpreters (see docs/tutorial-embedding.md)
make basic-wasm-modular
# Optional: 40×25 PETSCII canvas (GfxVideoState; bitmap + PNG sprites in browser)
make basic-wasm-canvas
```

Produces `web/basic.js` and `web/basic.wasm` (Asyncify-enabled), **`web/basic-modular.js`** / **`web/basic-modular.wasm`** for **`tutorial-embed.js`**, and optionally `web/basic-canvas.js` / `web/basic-canvas.wasm` plus **`web/canvas.html`** for a Canvas 2D PETSCII screen. After **`make basic-wasm-modular`**, open **`web/tutorial.html`** for a step-by-step **getting started** page with multiple embedded interpreters (see also **`docs/tutorial-embedding.md`**). Serve `web/` over HTTP (e.g. `cd web && python3 -m http.server 8080`) and open in a browser. The terminal demo uses an inline **INPUT** field and keyboard routing for **GET** / **INKEY$**; see `web/README.md` for details.

**PETSCII canvas** (no Raylib): `make basic-wasm-canvas` produces `web/basic-canvas.js`, `web/basic-canvas.wasm`, and `web/canvas.html`. The page refreshes the canvas during `SLEEP` and loops via a shared RGBA framebuffer (PETSCII, `SCREEN 1` bitmap, and **`LOADSPRITE`/`DRAWSPRITE`** like **basic-gfx**). Try **`examples/gfx_canvas_demo.bas`**: paste into the canvas page, use **Upload to VFS** to add **`gfx_canvas_demo.png`** (same file is copied to **`web/gfx_canvas_demo.png`** for local fetch tests), then Run.

**Canvas WASM vs `basic-gfx`**: The **same** `basic.c` runs in both. In the browser, the interpreter must periodically **`emscripten_sleep`** so the tab can paint and handle keys. Tight loops with little output can still make Chrome report “Page Unresponsive” while **`basic-gfx`** feels fine. For a small repro, see **`examples/nested_dim_print.bas`** and **`examples/wasm_canvas_hang_probe.bas`**.

**Automated WASM smoke tests** (headless Chromium via Playwright): install `pip install -r tests/requirements-wasm.txt`, run `python3 -m playwright install chromium`, then **`make wasm-test`**, **`make wasm-canvas-test`**, **`make wasm-canvas-charset-test`** (regression for `#OPTION charset lower`, `CHR$(32)` / `CHR$(65)`, with and without **`-petscii`**), and **`make wasm-tutorial-test`**. On **push to `main`**, workflow **`.github/workflows/wasm-tests.yml`** runs the same Playwright suite. Tagged releases and **nightly** also build WASM; artifacts include `rgc-basic-wasm.tar.gz` (terminal, modular tutorial files, and canvas).

#### Manual compilation

If you prefer to invoke the compiler directly:

- **Linux / WSL**
  ```bash
  gcc -std=c99 -Wall -O2 basic.c -lm -o basic
  ```
  or
  ```bash
  clang -std=c99 -Wall -O2 basic.c -lm -o basic
  ```
- **macOS**
Install the Xcode command line tools if you have not already:
  ```bash
  xcode-select --install
  ```
  Then build with:
  ```bash
  clang -std=c99 -Wall -O2 basic.c -lm -o basic
  ```
- **Windows (MSVC)**
From a “Developer Command Prompt for VS”:
  ```bat
  cl /std:c11 /W4 /O2 basic.c
  ```
  This will produce `basic.exe`.
- **Windows (MinGW‑w64)**
In a MinGW‑w64 shell:
  ```bash
  gcc -std=c99 -Wall -O2 basic.c -lm -o basic.exe
  ```

## Credits

The original idea was based on a BASIC project by David Plummer. His video is worth watching:

[https://www.youtube.com/watch?v=PyUuLYJLhUA](https://www.youtube.com/watch?v=PyUuLYJLhUA)
