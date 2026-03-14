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

## Commodore BASIC v2–style interpreter written in C.

Expanded from original by [David Plummer](https://github.com/davepl/pdpsrc/tree/main/bsd/basic)

Line-numbered BASIC interpreter inspired by CBM BASIC v2 as found on classic Commodore machines.

Unlike emulators, this is a BASIC interpreter that, while a project still very much in development, can already do real work.

For example reading and writing files.



## 💾 DOWNLOADS

[The latest binaries for Win/Mac/Linux are in ***Releases***](https://github.com/omiq/cbm-basic/releases/). 

Extract the files after downloading.

Each release archive includes the interpreter binary and the **`examples`** folder so you can run programs such as `./basic examples/trek.bas` (or `basic.exe examples\trek.bas` on Windows) from the unpacked directory.

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

- **Programs with or without line numbers**
  - Classic **line-numbered programs** loaded from a text file (`10 ...`, `20 ...`, etc.).
  - Also supports **numberless programs**: if the first non‑blank line has no leading digits, synthetic line numbers are assigned internally (you can still use labels and structured control flow).
- **Core statements**
  - **`PRINT` / `?`**: output expressions, with `;` (no newline) and `,` (zone/tab) separators; wrapping defaults to a 40‑column C64‑style width.
  - **`INPUT`**: read numeric or string variables from standard input, with optional prompt.
  - **`GET`**: single‑key input into a string variable, without waiting for Enter (e.g. `GET K$`). Enter/Return is returned as `CHR$(13)` so `ASC(K$)=13` works for “press Enter” checks.
  - **`LET`** (optional): assignment; you can also assign with `A=1` without `LET`.
  - **`IF ... THEN`**: conditional execution, supporting comparisons, `AND`/`OR`, and optional line-number or label jumps.
  - **`GOTO`**: jump to a given line number **or label** (e.g. `GOTO 100` or `GOTO GAMELOOP`).
  - **`GOSUB` / `RETURN`**: subroutines with a fixed-depth stack; targets may be line numbers or labels.
  - **`ON expr GOTO` / `ON expr GOSUB`**: multi-branch jumps; e.g. `ON N GOTO 100,200,300` or `ON K GOSUB 500,600`.
  - **`FOR` / `NEXT`**: numeric loops, including `STEP` with positive or negative increments.
  - **`DIM`**: declare 1‑D or multi‑dimensional numeric or string arrays (e.g. `DIM A(10)`, `DIM B(2,3)`).
  - **`REM`** and **`'`**: comments to end of line.
  - **`END` / `STOP`**: terminate program execution.
  - **`READ` / `DATA`**: load numeric and string literals from `DATA` statements into variables.
  - **`DEF FN`**: define simple user functions, e.g. `DEF FNY(X) = SIN(X)`.
  - **`POKE`**: accepted as a no‑op (for compatibility with old listings; it does not touch real memory).
  - **`CLR`**: resets all variables to 0/empty, clears GOSUB/FOR stacks and DATA pointer; DEF FN definitions are kept.
  - **File I/O (CBM-style)**:
    - **`OPEN lfn, device, secondary, "filename"`** — open a file (device 1 = disk/file; secondary 0 = read, 1 = write, 2 = append). Filename is a path in the current directory.
    - **`PRINT# lfn, expr [,|; expr ...]`** — write to the open file (like `PRINT` to file).
    - **`INPUT# lfn, var [, var ...]`** — read from the open file into variables (one token per variable; comma/newline separated).
    - **`GET# lfn, stringvar`** — read one character from the file into a string variable.
    - **`CLOSE [lfn [, lfn ...]]`** — close file(s); `CLOSE` with no arguments closes all.
    - **`ST`** — system variable set after `INPUT#`/`GET#`: 0 = success, 64 = end of file, 1 = error / file not open. Use e.g. `IF ST <> 0 THEN GOTO done`.
- **Variables**
  - **Numeric variables**: `A`, `B1`, `AB`, `ATAKFLAG`, etc. Names may be longer than two characters; CBM-style **first two characters** identify the variable (e.g. `ATAKFLAG` and `ATA` refer to the same variable).
  - **String variables**: names ending in `$`, e.g. `A$`, `NAME$`.
  - **Arrays**: 1‑D or multi‑dimensional, e.g. `A(10)`, `A$(20)`, `C(2,3)`. Index is 0‑based internally; `DIM A(10)` allows indices `0..10`; `DIM C(2,3)` gives a 3×4 matrix.
- **Intrinsic functions**
  - **Math**: `SIN`, `COS`, `TAN`, `ABS`, `INT`, `SQR`, `SGN`, `EXP`, `LOG`, `RND`.
  - **Strings**:
    - `LEN`, `VAL`, `STR$`, `CHR$`, `ASC`.
    - `UCASE$`, `LCASE$`: convert string to upper or lower case (ASCII).
    - `MID$`, `LEFT$`, `RIGHT$` with C64‑style semantics:
      - `MID$(S$, start)` or `MID$(S$, start, len)` (1‑based `start`).
      - `LEFT$(S$, n)` – first `n` characters.
      - `RIGHT$(S$, n)` – last `n` characters.
  - **Formatting**: `TAB` and `SPC` for horizontal positioning in `PRINT`.


### Additional/Non-Standard BASIC Commands

- **`SLEEP`**: pause execution for a number of 60 Hz “ticks” (e.g., `SLEEP 60` ≈ 1 second).

### Tokenised PETSCII shortcuts inside strings

- **Inline `{TOKENS}`**:
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
- **`LOCATE`**:
  - Moves the cursor without printing: e.g. `LOCATE 10,5` positions the cursor at column 10, row 5 before the next `PRINT`.
- **`TEXTAT`**:
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

- **`-petscii` / `--petscii`**: enable PETSCII/ANSI mode so that certain `CHR$` control codes
  (cursor movement, clear screen, colors, etc.) are translated to ANSI escape sequences.
- **`-palette ansi|c64`**: choose how PETSCII colors are mapped:
  - **`ansi`** (default): map colors to standard 16-color ANSI SGR codes.
  - **`c64`** or **`c64-8bit`**: use 8‑bit (`38;5;N`) color indices chosen to approximate
    the classic C64 palette. This is most consistent on terminals that support 256 colors.

You can also enable a **PETSCII/ANSI mode** that understands common C64 control codes inside strings and `CHR$` output:

```bash
./basic -petscii hello.bas
```

In `-petscii` mode, `CHR$` maps a few PETSCII control bytes to ANSI escape sequences (others print as-is):

- **Screen control**
  - **`CHR$(147)`**: clear screen and home cursor (maps to `ESC[2J ESC[H]`).
  - **`CHR$(17)`**: cursor down (`ESC[B]`).
  - **`CHR$(145)`**: cursor up (`ESC[A]`).
  - **`CHR$(29)`**: cursor right (`ESC[C]`).
  - **`CHR$(157)`**: cursor left (`ESC[D]`).
  - **`CHR$(18)`**: reverse video on (`ESC[7m]`).
  - **`CHR$(146)`**: reverse video off (`ESC[27m]`).
- **Basic text colors** (ANSI approximations of C64 colors)
  - **`CHR$(144)`**: black (`ESC[30m]`).
  - **`CHR$(5)`**: white (`ESC[37m]`).
  - **`CHR$(28)`**: red (`ESC[31m]`).
  - **`CHR$(159)`**: cyan (`ESC[36m]`).
  - **`CHR$(156)`**: purple (`ESC[35m]`).
  - **`CHR$(30)`**: green (`ESC[32m]`).
  - **`CHR$(31)`**: blue (`ESC[34m]`).
  - **`CHR$(158)`**: yellow (`ESC[33m]`).
  - **`CHR$(129)`**: orange (`ESC[38;5;208m]`).
  - **`CHR$(149)`**: brown (`ESC[33m]`).
  - **`CHR$(150)`**: light red (`ESC[91m]`).
  - **`CHR$(151)`**: dark gray (`ESC[90m]`).
  - **`CHR$(152)`**: medium gray (`ESC[37m]`).
  - **`CHR$(153)`**: light green (`ESC[92m]`).
  - **`CHR$(154)`**: light blue (`ESC[94m]`).
  - **`CHR$(155)`**: light gray (`ESC[97m]`).

If you do not pass a file name, the interpreter will print usage information:

```text
Usage: basic [-petscii] [-palette ansi|c64] <program.bas>
```

### Source normalization (compact CBM style)

Program text is normalized at load time so **compact CBM BASIC** without spaces around keywords is accepted. For example: `IFX<0THEN`, `FORI=1TO9`, `GOTO410`, `GOSUB5400`, and similar forms are rewritten with spaces so the parser recognises `IF`/`THEN`, `FOR`/`TO`/`NEXT`, `GOTO`, and `GOSUB`. This helps run listings that were saved with minimal whitespace.

### Included example programs

The **`examples`** folder (included in release archives) contains:

- **`dartmouth.bas`**: classic Dartmouth BASIC tutorial; exercises `PRINT`, `INPUT`, `IF`, `FOR/NEXT`, `DEF FN`, `READ`/`DATA`, and more.
- **`trek.bas`**: Star Trek–style game; exercises `GET`, `ON GOTO`/`GOSUB`, multi-dimensional arrays, and PETSCII-style output.
- **`chr.bas`**: PETSCII/ANSI color and control-code test (run with `-petscii`).
- **`examples/testdef.bas`**, **`tests/read_data.bas`**: small regressions for `DEF FN` and `READ`/`DATA`.
- **`test_dim2d.bas`**, **`test_get.bas`**: multi-dimensional arrays and `GET` Enter handling.
- **`tests/fileio.bas`**, **`tests/fileeof.bas`**, **`tests/test_get_hash.bas`**: file I/O regression tests.
- **`examples/fileio_basics.bas`**: write and read a file (OPEN, PRINT#, INPUT#, CLOSE) with step-by-step comments.
- **`examples/fileio_loop.bas`**: read until end of file using the ST status variable (ST=0/64/1).
- **`examples/fileio_get.bas`**: read one character at a time with GET#.
- **`guess.bas`**, **`adventure.bas`**, **`printx.bas`**, and others for various features.

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