# CBM-BASIC
```
   _____ ____  __  __        ____           _____ _____ _____ 
  / ____|  _ \|  \/  |      |  _ \   /\    / ____|_   _/ ____|
 | |    | |_) | \  / |______| |_) | /  \  | (___   | || |     
 | |    |  _ <| |\/| |______|  _ < / /\ \  \___ \  | || |     
 | |____| |_) | |  | |      | |_) / ____ \ ____) |_| || |____ 
  \_____|____/|_|  |_|      |____/_/    \_\_____/|_____\_____|
                                                                                                                   
  .............................................................
```

## Commodore BASIC v2–style interpreter written in C.

Expanded from original by [David Plummer](https://github.com/davepl/pdpsrc/tree/main/bsd/basic)

Line-numbered BASIC interpreter inspired by CBM BASIC v2 as found on classic Commodore machines.

## DOWNLOADS

[The latest binaries for Win/Mac/Linux are in ***Releases***](https://github.com/omiq/cbm-basic/releases/)

### macOS Gatekeeper note

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

## Features

- **Line-numbered programs** loaded from a text file (`10 ...`, `20 ...`, etc.).
- **Core statements**
  - **`PRINT` / `?`**: output expressions, with `;` (no newline) and `,` (zone/tab) separators.
  - **`INPUT`**: read numeric or string variables from standard input, with optional prompt.
  - **`LET`** (optional): assignment; you can also assign with `A=1` without `LET`.
  - **`IF ... THEN`**: conditional execution, supporting comparisons and optional line-number jumps.
  - **`GOTO`**: jump to a given line number.
  - **`GOSUB` / `RETURN`**: subroutines with a fixed-depth stack.
  - **`FOR` / `NEXT`**: numeric loops, including `STEP` with positive or negative increments.
  - **`DIM`**: declare 1‑D numeric or string arrays.
  - **`REM`** and **`'`**: comments to end of line.
  - **`SLEEP`**: pause execution for a number of 60 Hz “ticks” (e.g., `SLEEP 60` ≈ 1 second).
  - **`END` / `STOP`**: terminate program execution.
  - **`READ` / `DATA`**: load numeric and string literals from `DATA` statements into variables.
  - **`DEF FN`**: define simple user functions, e.g. `DEF FNY(X) = SIN(X)`.
  - **`POKE`**: accepted as a no‑op (for compatibility with old listings; it does not touch real memory).
- **Variables**
  - **Numeric variables**: `A`, `B1`, `AB`, etc.
  - **String variables**: names ending in `$`, e.g. `A$`, `NAME$`.
  - **1‑D arrays**: `A(10)`, `A$(20)`. Index is 0‑based internally; `DIM A(10)` allows indices `0..10`.
- **Intrinsic functions**
  - **Math**: `SIN`, `COS`, `TAN`, `ABS`, `INT`, `SQR`, `SGN`, `EXP`, `LOG`, `RND`.
  - **Strings**: `LEN`, `VAL`, `STR$`, `CHR$`, `ASC`.
  - **Formatting**: `TAB` and `SPC` for horizontal positioning in `PRINT`.

## Requirements

- A C compiler with C99 (or newer) support:
  - Linux / WSL: `gcc` or `clang`
  - macOS: Xcode Command Line Tools (`clang`)
  - Windows:
    - MSVC (Visual Studio / Build Tools), or
    - MinGW‑w64 (`gcc`)

## Building

You can either use the provided `Makefile` (recommended) or compile manually.

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

## Usage

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

### Included example programs

- **`dartmouth.bas`**: a port of a classic Dartmouth BASIC tutorial program that exercises `PRINT`, `INPUT`, `IF`, `FOR/NEXT`, `DEF FN`, `READ`/`DATA`, and more.
- **`tests/def_fn.bas`**: small regression for `DEF FN` and function calls.
- **`tests/read_data.bas`**: small regression for `READ`/`DATA` with numeric and string arrays.

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

`This README describes the current feature set of the interpreter as implemented in `basic.c` and is subject to change without notice`
