# CBM-BASIC

```
   _____ ____  __  __        ____           _____ _____ _____ 
  / ____|  _ \|  \/  |      |  _ \   /\    / ____|_   _/ ____|
 | |    | |_) | \  / |______| |_) | /  \  | (___   | || |     
 | |    |  _ <| |\/| |______|  _ < / /\ \  \___ \  | || |     
 | |____| |_) | |  | |      | |_) / ____ \ ____) |_| || |____ 
  \_____|____/|_|  |_|      |____/_/    \_\_____/|_____\_____|
  ............................................................
```

## Commodore BASIC –style interpreter written in C.

CBM-BASIC is, as the name suggests, a BASIC interpreter *inspired* by CBM BASIC v2 as found on classic Commodore machines. This means while you *can* use `GOTO`, you don't *have* to. You do you. This is a readme file, not the code police.

Unlike emulators, this is a BASIC interpreter that can already do real work: reading and writing files, user-defined functions, structured control flow, and more. In addition to the **terminal interpreter** (`basic`), there is a full **graphical interpreter** (`basic-gfx`) built with Raylib — a complete 40×25 PETSCII windowed environment with `POKE`/`PEEK` screen memory, `INKEY$`, `TI`/`TI$`, and `.seq` art viewers.

## Why Commodore BASIC?

The project started as an expansion on an original LLM-generated demo project by [David Plummer](https://github.com/davepl/pdpsrc/tree/main/bsd/basic). As I played with it, and added to it, I had fun. That's enough reason for me, and nobody is going to take your favourite toolchain away because this exists so calm down, sheesh.

See `CHANGELOG.md` for a versioned history of changes (starting from **1.0.0 – 2026-03-09**).

## 💾 DOWNLOADS

[The latest binaries for Win/Mac/Linux are in Releases](https://github.com/omiq/cbm-basic/releases/). For bleeding-edge builds from `main`, use the [**nightly** release](https://github.com/omiq/cbm-basic/releases/tag/nightly) (built automatically every night).

Extract the files after downloading.

Each release archive includes the terminal interpreter (`basic`), the graphical interpreter (`basic-gfx`), and the `examples` folder. Run programs such as `./basic examples/trek.bas` or `./basic-gfx -petscii examples/gfx_colaburger_viewer.bas` (Windows: `basic.exe`, `basic-gfx.exe`).

![gitscreenshot1.png](https://github.com/omiq/cbm-basic/blob/main/git-screenshot1.png)



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
  - `#OPTION petscii` / `#OPTION charset lower` / `#OPTION palette c64` — mirror command-line options; file overrides CLI.
  - `#INCLUDE "path"` — splice another file at that point. Recommend numberless mode when using includes; duplicate line numbers and labels error.
- **Programs with or without line numbers**
  - Classic **line-numbered programs** loaded from a text file (`10 ...`, `20 ...`, etc.).
  - Also supports **numberless programs**: if the first non‑blank line has no leading digits, synthetic line numbers are assigned internally (you can still use labels and structured control flow).
- **Core statements**
  - `PRINT` / `?`: output expressions, with `;` (no newline) and `,` (zone/tab) separators; wrapping defaults to a 40‑column C64‑style width.
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
  - `READ` / `DATA`: load numeric and string literals from `DATA` statements into variables. `RESTORE` resets the DATA pointer so the next `READ` uses the first value again (C64-style).
  - `DEF FN`: define simple user functions, e.g. `DEF FNY(X) = SIN(X)`.
  - **User-defined FUNCTIONS** (implemented): multi-line, multi-parameter functions:
    - `FUNCTION name [(param1, param2, ...)]` … `RETURN [expr]` … `END FUNCTION`.
    - Call with brackets always: `result = add(3, 5)` or `sayhi()` for side effects.
    - `RETURN expr` returns a value; `RETURN` or `END FUNCTION` with no prior RETURN yields 0/`""` in expression context.
    - Parameters are local; recursion supported. See `docs/user-functions-plan.md` for the design.
  - `POKE`: accepted as a no‑op (for compatibility with old listings; it does not touch real memory).
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
    - `UCASE$`, `LCASE$`: convert string to upper or lower case (ASCII).
    - `MID$`, `LEFT$`, `RIGHT$` with C64‑style semantics:
      - `MID$(S$, start)` or `MID$(S$, start, len)` (1‑based `start`).
      - `LEFT$(S$, n)` – first `n` characters.
      - `RIGHT$(S$, n)` – last `n` characters.
    - `INSTR(source$, search$)` – returns the 1‑based index of `search$` in `source$`, or `0` if not found.
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

- Inline `{TOKENS}`:
  - Within double-quoted strings, the interpreter recognises `{...}` patterns and expands them to `CHR$()` calls **at load time**.
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
Usage: basic [-petscii] [-petscii-plain] [-palette ansi|c64] <program.bas>
```

### Shell scripting: standard I/O and arguments

You can use the interpreter for shell-script style tasks:

- **Standard input/output**  
`INPUT` reads from standard input (one line or token at a time). `PRINT` writes to standard output. So you can pipe data in and out:
  - `echo 42 | ./basic program.bas`
  - `./basic program.bas > out.txt`
  Errors and usage go to **stderr**; only program output goes to stdout when you redirect.
- **Command-line arguments**  
Anything after the script path is available to the program:
  - `./basic script.bas first second`
  - In the script: `ARG$(0)` = script path, `ARG$(1)` = `"first"`, `ARG$(2)` = `"second"`, `ARGC()` = 2.
- **Running shell commands**  
`SYSTEM("command")` runs the command and returns its exit code. `EXEC$("command")` runs the command and returns its stdout as a string (e.g. `PRINT EXEC$("date")`).  
Example: `examples/scripting.bas` demonstrates `ARGC()`, `ARG$()`, `SYSTEM()`, and `EXEC$()`.

### Source normalization (compact CBM style)

Program text is normalized at load time so **compact CBM BASIC** without spaces around keywords is accepted. For example: `IFX<0THEN`, `FORI=1TO9`, `GOTO410`, `GOSUB5400`, and similar forms are rewritten with spaces so the parser recognises `IF`/`THEN`, `FOR`/`TO`/`NEXT`, `GOTO`, and `GOSUB`. This helps run listings that were saved with minimal whitespace.

---

### 🎨 Graphical interpreter (basic-gfx)

Releases include **basic-gfx** — a full graphical version of the interpreter built with Raylib. It provides a 40×25 PETSCII windowed display with `POKE`/`PEEK` screen memory, `INKEY$`, `TI`/`TI$`, `.seq` art viewers, and full PETSCII symbols:

![Cola Burger](https://github.com/omiq/cbm-basic/blob/main/git-screenshot2.png)



(building requires Raylib to be installed - build the graphics target via `make basic-gfx)`

- `./basic-gfx examples/gfx_poke_demo.bas`
- `./basic-gfx examples/gfx_charset_demo.bas`
- `./basic-gfx examples/gfx_key_demo.bas`
- `./basic-gfx -petscii examples/gfx_text_demo.bas`
- `./basic-gfx -petscii examples/gfx_inkey_demo.bas`
- `./basic-gfx -petscii examples/gfx_jiffy_game_demo.bas`
- `./basic-gfx -petscii -charset lower examples/gfx_colaburger_viewer.bas` — displays `.seq` art with correct PETSCII rendering (lowercase charset for “Welcome”, “Press”, etc.).

**Keyboard polling (basic-gfx)**:

- BASIC can poll a simple key-down map via `PEEK(56320 + code)` where 56320 is 0xDC00.
- Supported codes include ASCII `A`–`Z`, `0`–`9`, Space (32), Enter (13), Esc (27), and C64 cursor codes Up (145), Down (17), Left (157), Right (29).

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

**Window title (basic-gfx)**:

- Set the window title via `#OPTION gfx_title "My Game"` or the CLI `-gfx-title "My Game"`. Default is `CBM-BASIC GFX`.

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
  - String and numeric comparisons are both supported.
  - You may `THEN` jump to a line number (`IF A>10 THEN 100`) or execute inline statements after `THEN`.
- **Random numbers**:
  - `RND(X)` behaves like classic BASIC; a negative argument reseeds the generator.

This README describes the current feature set of the interpreter as implemented in `basic.c` and is subject to change without notice.

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
