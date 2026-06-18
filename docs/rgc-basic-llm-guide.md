# Writing rgc-basic: a guide for LLM agents

This document is for an AI assistant generating **rgc-basic** programs
(`.bas` files) on a user's behalf. It exists because the single most
common failure mode is inventing keywords that do not exist, or assuming
this dialect matches Commodore 64 BASIC, QBASIC, or another BASIC the
model has seen more of in training. It does not.

The authoritative, machine-readable companion to this guide is
[`spec.json`](../spec.json) at the repo root. Both files are generated
from the interpreter source (`basic.c`) by
`tools/rgc_lint/gen_spec.py`, so they cannot drift from the runtime.

## The one rule that matters

**If a name is not in the keyword tables below (or in `spec.json`), it
does not exist. Do not use it.** There is no `PRINTLN`, no `BEEP`, no
`CLS()` with parentheses, no `INPUT$`. When you reach for a built-in,
confirm it is in the list first. A misspelled or imagined keyword is the
error the user will hit immediately.

## Verify before you hand code back

rgc-basic ships a linter. After writing a program, run it and fix every
finding before claiming the program is done:

```sh
python3 -m tools.rgc_lint.cli --tier=modern yourprogram.bas
# machine-readable:
python3 -m tools.rgc_lint.cli --tier=modern --json yourprogram.bas
```

- **E003** means you used a keyword that does not exist. Fix the spelling
  or remove it.
- **E001 / W001** are portability findings (see tiers below). They only
  matter if the user wants the program to transpile to a retro target.

If the `basic` binary is available, the ultimate check is running it:
`./basic yourprogram.bas`.

## Portability tiers

Every keyword carries a tier. Pick a tier based on where the program must
run, then stay inside it.

- **portable** — runs on rgc-basic and transpiles to ugBASIC retro
  targets (C64, etc.). Use this tier if the user mentions retro hardware
  or transpiling.
- **modern** — rgc-basic only (native binary + WASM/browser). No retro
  equivalent. Fine for browser games and tools; will not transpile.
- **conditional** — runs everywhere but behaviour or availability differs
  per target. Check the note.

Lint with `--tier=portable` to enforce the retro-safe subset, or
`--tier=modern` (the default for new browser programs) to allow
everything.

## Syntax essentials

These are real, verified idioms. Mirror them.

**Output and string building** (use `+` to concatenate, `;` to suppress
newline):

```basic
PRINT "hello, " + name$
PRINT "score: "; SC; "  lives: "; LV
```

**Input** (`INPUT` for a line, `GET` for a single key, `INKEY$` for a
non-blocking poll):

```basic
INPUT "what is your name? "; name$
PRINT "press a key"
LP:
  GET i$
  IF i$ = "" THEN GOTO LP
PRINT "you pressed: " + i$
```

**Loops** (`FOR`/`NEXT`, `WHILE`/`WEND`, `DO`/`LOOP UNTIL`):

```basic
FOR I = 1 TO 10
  PRINT I
NEXT I

WHILE running
  GOSUB update
WEND
```

**Conditionals** (`THEN` is required; `ELSEIF`/`ELSE`/`ENDIF` for blocks):

```basic
IF hp <= 0 THEN PRINT "game over" : END
IF k$ = "w" THEN
  y = y - 1
ELSEIF k$ = "s" THEN
  y = y + 1
ENDIF
```

**Subroutines and functions:**

```basic
GOSUB drawhud
...
drawhud:
  PRINT "HP "; hp
RETURN

FUNCTION DOUBLE(N)
  RETURN N * 2
END FUNCTION
```

**Multiple statements per line** with `:` (common in classic style):

```basic
BX = 160 : BY = 100 : BR = 6
```

**Graphics** (modern tier; `basic-gfx` / canvas WASM). `SCREEN` selects a
mode, then draw with primitives:

```basic
SCREEN 1
BACKGROUND 0
FILLCIRCLE x, y, r, WHITE
RECT 0, 0, 319, 199, WHITE
DRAWTEXT 8, 8, "SCORE " + STR$(sc), WHITE
IF KEYDOWN(KEY_Q) THEN END
```

## Dialect gotchas

- **Numeric line numbers are optional.** Use labels (`mainloop:` plus
  `GOTO mainloop`) for new code. If you use line numbers, number every
  code line; mixing numbered and unnumbered lines is an error (E002).
- **Classic crunching works but is fragile.** The interpreter restores
  spaces around `IF FOR GOTO GOSUB NEXT THEN TO AND OR MOD XOR` when they
  are glued to operands (`NEXTI` becomes `NEXT I`). It does **not** do
  this for other keywords, and `FORMAT` becomes `FOR MAT`. Write spaced
  code; do not rely on crunching.
- **String functions end in `$`**: `CHR$`, `LEFT$`, `MID$`, `STR$`,
  `UCASE$`. Numeric functions do not.
- **Named colour constants exist** (`WHITE`, `RED`, `CYAN`, ... 0-15) plus
  `TRUE`, `FALSE`, `PI`.
- **`#OPTION` directives** (with the hash) configure a program, e.g.
  `#OPTION PETSCII`. Per-script intent; see `language.md`.

## Full keyword reference

Generated from `basic.c`. This is exhaustive: nothing outside this list
is a built-in. `tier` and `note` come from the portability rules.

<!-- BEGIN GENERATED KEYWORDS -->

### Statements / keywords (142)

| name | tier | note |
| --- | --- | --- |
| `AND` | portable |  |
| `ANTIALIAS` | modern |  |
| `ASSERT` | modern |  |
| `BACKGROUND` | portable |  |
| `BACKGROUNDRGB` | modern |  |
| `BITMAPCLEAR` | modern |  |
| `BUFFERFETCH` | modern |  |
| `BUFFERFREE` | modern |  |
| `BUFFERNEW` | modern |  |
| `CASE` | modern | CASE clause inside SELECT CASE; supports comma lists, CASE IS <relop> expr, CASE lo TO hi, CASE ELSE |
| `CHDIR` | modern |  |
| `CIRCLE` | portable |  |
| `CLOSE` | conditional |  |
| `CLR` | portable |  |
| `CLS` | portable |  |
| `COLOR` | portable | indices 0..15; modern accepts 0..255 in SCREEN 3 |
| `COLORRGB` | modern | use COLOR n (0..15) for portable code |
| `COLOUR` | portable |  |
| `COLOURRGB` | modern |  |
| `CONTINUE` | modern | CONTINUE FOR / CONTINUE DO / CONTINUE WHILE — skip to the loop's test/increment; kind keyword required |
| `CURSOR` | conditional | PETSCII terminal control; behaviour/availability differs across retro targets |
| `DATA` | portable |  |
| `DEF` | portable | DEF FN — transpiler maps to ugBASIC DEFINE |
| `DICTDEL` | modern |  |
| `DICTFREE` | modern |  |
| `DICTPUSH` | modern |  |
| `DICTSET` | modern |  |
| `DICTSETBOOL` | modern |  |
| `DICTSETNULL` | modern |  |
| `DICTUNPACK` | modern |  |
| `DIM` | portable |  |
| `DO` | portable |  |
| `DOUBLEBUFFER` | modern | ugBASIC uses WAIT VBL implicitly; retro builds usually accept tearing or use sprite-only updates |
| `DOWN` | conditional | PETSCII terminal control; behaviour/availability differs across retro targets |
| `DRAWSPRITE` | portable |  |
| `DRAWSPRITETILE` | portable |  |
| `DRAWTEXT` | portable | ugBASIC has equivalent on bitmap modes |
| `ELLIPSE` | portable |  |
| `ELSE` | portable |  |
| `ELSEIF` | portable |  |
| `END` | portable | END / END IF / END FUNCTION / END SELECT all portable |
| `EXIT` | portable | bare EXIT or EXIT DO leaves the innermost DO; EXIT FOR / EXIT WHILE leave the innermost FOR / WHILE |
| `FILLCIRCLE` | portable |  |
| `FILLELLIPSE` | modern |  |
| `FILLPOLYGON` | modern |  |
| `FILLRECT` | portable |  |
| `FILLTRIANGLE` | modern |  |
| `FLOODFILL` | modern |  |
| `FN` | portable |  |
| `FOR` | portable |  |
| `FOREACH` | modern |  |
| `FUNCTION` | portable | transpiler maps to ugBASIC PROCEDURE |
| `GET` | portable |  |
| `GETBYTE` | modern |  |
| `GOSUB` | portable |  |
| `GOTO` | portable |  |
| `IF` | portable |  |
| `IMAGE` | modern | all IMAGE NEW/CREATE/COPY/GRAB/LOAD/SAVE/BLEND/DRAW/FREE forms |
| `IN` | portable |  |
| `INK` | portable |  |
| `INPUT` | portable |  |
| `JOIN` | modern |  |
| `JSONUNPACK` | modern | rgc-only: JSONUNPACK src$, path$ INTO arr$ |
| `LET` | portable |  |
| `LINE` | portable |  |
| `LOAD` | conditional | raw bytes into virtual memory — retro semantics target-specific |
| `LOADMUSIC` | modern |  |
| `LOADSCREEN` | modern |  |
| `LOADSOUND` | modern | WAV decode unavailable on retro — use ugBASIC SAY / SOUND / MUSIC primitives instead |
| `LOADSPRITE` | portable |  |
| `LOCATE` | portable |  |
| `LOOP` | portable |  |
| `MAPLOAD` | modern | JSON parser too large for retro 64K — embed level data as DATA statements |
| `MAPSAVE` | modern |  |
| `MEMCPY` | conditional |  |
| `MEMSET` | conditional |  |
| `MOD` | portable |  |
| `MUSICLOOP` | modern |  |
| `MUSICVOLUME` | modern |  |
| `NEXT` | portable |  |
| `NOT` | portable |  |
| `OBJLOAD` | modern |  |
| `OBJSAVE` | modern |  |
| `OFF` | conditional | PETSCII terminal control; behaviour/availability differs across retro targets |
| `ON` | portable |  |
| `OPEN` | conditional | filesystem story varies per retro target — disk vs cassette |
| `OR` | portable |  |
| `OVERLAY` | modern | no portable equivalent — for HUDs in portable, paint last directly to active plane |
| `PALETTELOAD` | modern |  |
| `PALETTERESET` | modern |  |
| `PALETTEROTATE` | modern |  |
| `PALETTESAVE` | modern |  |
| `PALETTESET` | modern |  |
| `PALETTESETHEX` | modern |  |
| `PAPER` | portable |  |
| `PAUSEMUSIC` | modern |  |
| `PLAYMUSIC` | modern |  |
| `PLAYSOUND` | modern |  |
| `POKE` | conditional | addresses are target-specific; transpiler may refuse |
| `POLYGON` | modern |  |
| `PRESET` | portable |  |
| `PRINT` | portable |  |
| `PSET` | portable |  |
| `PUTBYTE` | modern |  |
| `READ` | portable |  |
| `RECT` | portable |  |
| `REM` | portable |  |
| `RESTORE` | portable |  |
| `RESUMEMUSIC` | modern |  |
| `RETURN` | portable |  |
| `RVS` | conditional | PETSCII terminal control; behaviour/availability differs across retro targets |
| `SCREEN` | param | SCREEN 0/1 portable; 2/3/4 RGBA-only |
| `SCREENCODES` | modern |  |
| `SCROLL` | modern | free-pan / zone / line scrolling — too target-specific for v1 |
| `SELECT` | modern | SELECT CASE … CASE … CASE ELSE … END SELECT; rgc-basic block dispatch (numeric/string, comma lists, IS relop, lo TO hi) |
| `SLEEP` | portable |  |
| `SORT` | modern |  |
| `SPLIT` | modern |  |
| `SPRITECOPY` | modern |  |
| `SPRITEMODIFY` | modern |  |
| `SPRITEMODULATE` | modern |  |
| `SPRITEVISIBLE` | portable |  |
| `STEP` | portable |  |
| `STOP` | portable |  |
| `STOPMUSIC` | modern |  |
| `STOPSOUND` | modern |  |
| `TEXTAT` | portable |  |
| `THEN` | portable |  |
| `TI` | portable |  |
| `TILE` | modern | two-word TILE DRAW/COUNT family; modern gfx |
| `TILEMAP` | modern | ugBASIC has its own tilemap primitives — defer to v2 |
| `TIMER` | portable | transpiler maps to ugBASIC PARALLEL PROCEDURE + SPAWN; native rgc-basic uses real timer |
| `TO` | portable |  |
| `TRIANGLE` | portable | v1.18: graphics primitive |
| `UNLOADMUSIC` | modern |  |
| `UNLOADSOUND` | modern |  |
| `UNLOADSPRITE` | portable |  |
| `UNTIL` | portable |  |
| `VSYNC` | portable |  |
| `WEND` | portable |  |
| `WHILE` | portable |  |
| `XOR` | portable |  |

### Functions (117)

| name | tier | note |
| --- | --- | --- |
| `ABS` | portable |  |
| `ANIMFRAME` | modern |  |
| `ARG` | modern |  |
| `ARGC` | modern |  |
| `ASC` | portable |  |
| `BUFFERLEN` | modern |  |
| `BUFFERPATH` | modern |  |
| `CHR` | portable |  |
| `COS` | portable |  |
| `CWD` | modern |  |
| `DEC` | portable |  |
| `DICTGET` | modern |  |
| `DICTGETBOOL` | modern |  |
| `DICTGETN` | modern |  |
| `DICTHAS` | modern |  |
| `DICTKEY` | modern |  |
| `DICTLEN` | modern |  |
| `DICTLOAD` | modern |  |
| `DICTNEW` | modern |  |
| `DICTTYPE` | modern |  |
| `DIR` | modern |  |
| `ENV` | modern |  |
| `EVAL` | modern |  |
| `EXEC` | modern |  |
| `EXP` | portable |  |
| `FIELD` | modern |  |
| `FILEEXISTS` | modern |  |
| `GETMOUSEX` | modern |  |
| `GETMOUSEY` | modern |  |
| `HEX` | portable |  |
| `HTTP` | modern | no network on retro hardware |
| `HTTPFETCH` | modern |  |
| `HTTPSTATUS` | modern |  |
| `INDEXOF` | modern |  |
| `INKEY` | portable |  |
| `INSTR` | portable |  |
| `INT` | portable |  |
| `ISMOUSEBUTTONDOWN` | modern |  |
| `ISMOUSEBUTTONPRESSED` | modern |  |
| `ISMOUSEBUTTONRELEASED` | modern |  |
| `ISMOUSEBUTTONUP` | modern |  |
| `ISMOUSEOVERSPRITE` | modern |  |
| `JOY` | portable |  |
| `JOYAXIS` | modern |  |
| `JOYSTICK` | portable |  |
| `JSON` | modern |  |
| `JSONBOOL` | modern |  |
| `JSONESC` | modern |  |
| `JSONKEY` | modern |  |
| `JSONLEN` | modern |  |
| `JSONNEW` | modern |  |
| `JSONNUM` | modern |  |
| `JSONPUT` | modern |  |
| `JSONPUTBOOL` | modern |  |
| `JSONPUTNULL` | modern |  |
| `JSONSTATUS` | modern |  |
| `JSONTYPE` | modern |  |
| `KEYDOWN` | portable |  |
| `KEYPRESS` | modern |  |
| `KEYUP` | portable |  |
| `LASTERROR` | modern |  |
| `LASTINDEXOF` | modern |  |
| `LCASE` | portable |  |
| `LEFT` | portable |  |
| `LEN` | portable |  |
| `LOG` | portable |  |
| `LTRIM` | modern |  |
| `MID` | portable |  |
| `MUSICCHANNELS` | modern |  |
| `MUSICLENGTH` | modern |  |
| `MUSICORDERS` | modern |  |
| `MUSICPATTERNS` | modern |  |
| `MUSICPEAK` | modern |  |
| `MUSICPLAYING` | modern |  |
| `MUSICSAMPLECOUNT` | modern |  |
| `MUSICSAMPLENAME` | modern |  |
| `MUSICTIME` | modern |  |
| `MUSICTITLE` | modern |  |
| `PALETTE` | modern |  |
| `PALETTEHEX` | modern |  |
| `PEEK` | conditional |  |
| `PLATFORM` | modern |  |
| `REPLACE` | modern |  |
| `RGCVERSION` | modern |  |
| `RIGHT` | portable |  |
| `RND` | portable |  |
| `RNDINT` | portable |  |
| `RTRIM` | modern |  |
| `SCROLLX` | modern |  |
| `SCROLLY` | modern |  |
| `SGN` | portable |  |
| `SHEETCOLS` | modern |  |
| `SHEETHEIGHT` | modern |  |
| `SHEETROWS` | modern |  |
| `SHEETWIDTH` | modern |  |
| `SIN` | portable |  |
| `SOUNDPLAYING` | modern |  |
| `SPC` | portable |  |
| `SPRITEAT` | modern |  |
| `SPRITECOLLIDE` | modern |  |
| `SPRITEFRAME` | portable |  |
| `SPRITEFRAMES` | modern |  |
| `SPRITEH` | modern |  |
| `SPRITETILES` | modern |  |
| `SPRITEW` | modern |  |
| `SQR` | portable |  |
| `STR` | portable |  |
| `STRING` | portable |  |
| `SYSTEM` | modern |  |
| `TAB` | portable |  |
| `TAN` | portable |  |
| `TICKMS` | modern |  |
| `TICKUS` | modern |  |
| `TILECOUNT` | modern |  |
| `TRIM` | modern |  |
| `UCASE` | portable |  |
| `VAL` | portable |  |

### Constants (22)

| name | tier | note |
| --- | --- | --- |
| `BLACK` | portable |  |
| `BLUE` | portable |  |
| `BROWN` | portable |  |
| `CYAN` | portable |  |
| `DARKGRAY` | portable |  |
| `DARKGREY` | portable |  |
| `FALSE` | portable |  |
| `GREEN` | portable |  |
| `LIGHTBLUE` | portable |  |
| `LIGHTGRAY` | portable |  |
| `LIGHTGREEN` | portable |  |
| `LIGHTGREY` | portable |  |
| `MEDGRAY` | portable |  |
| `MEDGREY` | portable |  |
| `ORANGE` | portable |  |
| `PI` | portable |  |
| `PINK` | portable |  |
| `PURPLE` | portable |  |
| `RED` | portable |  |
| `TRUE` | portable |  |
| `WHITE` | portable |  |
| `YELLOW` | portable |  |

<!-- END GENERATED KEYWORDS -->

## Where to look next

- [`spec.json`](../spec.json) — the same inventory, machine-readable.
- `docs/basic/rgc-basic/language.md` in the
  [retrodocs](https://docs.retrogamecoders.com) source — the human
  reference with full syntax and examples per feature.
- `examples/*.bas` — 120+ working programs to pattern-match against.
