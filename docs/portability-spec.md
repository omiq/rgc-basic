# RGC BASIC — portability spec (linter + transpiler)

Status: design v1, MVP linter in progress.

This doc defines the **rgc-basic-portable** subset and the toolchain that validates and translates it to retro-target binaries via [ugBASIC](https://ugbasic.iwashere.eu/). Goal: write one game, ship to **C64 / Atari / Amstrad / MSX / BBC / Spectrum / CoCo / Plus4** (whatever ugBASIC supports) **and** an enhanced 640×480 modern build using rgc-basic raylib features — from a single source tree.

## 1. Use case

Roguelike-class workflow: develop game on the smallest target, port to other 8-bit targets, then have an enhanced modern version that uses full RGBA / sprites / sound / overlays. Logic stays portable; rendering swaps per tier.

Roguelikes are an ideal fit because the gameplay vocabulary (grid map, entities, RNG, turn loop, text/PETSCII tiles) maps cleanly to retro hardware, and the visual layer is the only thing that wants enhancement on modern.

## 2. Goals + non-goals

### Goals

- **One source, two output tiers**: portable retro (via ugBASIC) and modern (native rgc-basic).
- **Authoritative subset definition** as machine-checkable rules, not prose.
- **Author-time feedback**: linter flags non-portable usage at write time, not at deploy.
- **CI gate**: portable examples linted as part of `make check`.
- **Independent value**: linter useful even before the transpiler ships.
- **Shared infra**: tokenizer / walker / rules table shared between linter and transpiler.

### Non-goals (v1)

- 100% of rgc-basic surface portable. The portable subset is a **discipline**, not a coverage target.
- Cross-target asset normalisation (per-target sprite resizing, palette remapping). Author owns multi-resolution assets.
- Sound parity. Each retro target has unique audio chip; portable subset is silent or beeps only.
- IDE squiggle-under integration in v1. CLI tool first; IDE wiring later.

## 3. Tiers

| Tier | Where it runs | Toolchain |
|---|---|---|
| **portable** | Any retro target ugBASIC supports + modern rgc-basic | `rgc-lint --tier=portable` → `rgc2ugb` → `ugbc -T <target>` → `.prg` / `.tap` / `.cas` |
| **modern** | rgc-basic native (basic-gfx) + browser WASM | `rgc-lint --tier=modern` (advisory) → `basic-gfx` direct |

Modern tier also runs portable code (it's a superset). The reverse never holds — portable refuses anything tagged modern.

## 4. Surface vocabulary

Rules table is the source of truth (`tools/rgc_lint/rules.json`). Categories:

| Category | Status | Notes |
|---|---|---|
| `PRINT`, `INPUT`, `LET`, `REM`, `'` | portable | |
| `IF / THEN / ELSE / ELSE IF / ELSEIF / END IF / ENDIF` | portable | block + inline |
| `FOR / NEXT / STEP`, `WHILE / WEND`, `DO / LOOP / UNTIL`, `EXIT`, `GOTO`, `GOSUB`, `RETURN`, `ON GOTO`, `ON GOSUB` | portable | |
| `DIM` (1-D + 2-D numeric / string arrays) | portable | |
| `READ / DATA / RESTORE` | portable | |
| `FUNCTION ... END FUNCTION` | portable | maps to ugBASIC `PROCEDURE` |
| `DEF FN` | portable | maps to ugBASIC `DEFINE` |
| `RND`, `INT`, `ABS`, `SGN`, `SIN`, `COS`, `SQR`, `MOD` | portable | |
| `CHR$`, `STR$`, `VAL`, `LEN`, `LEFT$`, `RIGHT$`, `MID$`, `INSTR`, `UCASE$`, `LCASE$`, `STRING$` | portable | |
| `INKEY$`, `KEYDOWN(code)` | portable | |
| `JOY()`, `JOYSTICK`, `FIRE` | portable | |
| `LOCATE`, `TEXTAT`, `CLS`, `COLOR`, `BACKGROUND`, `PAPER` | portable | |
| `SCREEN 0` (text) | portable | |
| `SCREEN 1` (320×200 1bpp) | portable | maps to ugBASIC `BITMAP ENABLE` on targets that support it |
| `SPRITE LOAD slot, "f.png" [, tw, th]` | portable | maps to ugBASIC `LOAD IMAGE` + `SPRITE` per-target |
| `SPRITE DRAW slot, x, y` | portable | |
| `SPRITE FRAME slot, n` | portable | for tile-sheet animation |
| `PSET`, `LINE`, `RECT`, `FILLRECT`, `CIRCLE`, `FILLCIRCLE` | portable | maps to ugBASIC primitives |
| `DRAWTEXT x, y, text$` | portable | maps to ugBASIC `LOCATE` + bitmap text |
| `SLEEP n` | portable | maps to ugBASIC `WAIT n CYCLES` (or per-target equivalent) |
| `VSYNC` | portable | maps to ugBASIC `WAIT VBL` |
| `TI`, `TI$` | portable | (ugBASIC has equivalent counters) |
| **Modern-only** | | |
| `SCREEN 2 / 3 / 4` (RGBA / indexed-256 / hi-RGBA) | modern | retro hardware can't do RGBA |
| `COLORRGB`, `BACKGROUNDRGB` | modern | |
| `OVERLAY ON / OFF / CLS` | modern | |
| `IMAGE CREATE / BLEND / DRAW / NEW / COPY / GRAB / LOAD / SAVE` | modern | |
| `LOADSCREEN`, `DOUBLEBUFFER` | modern | |
| `PALETTESET / PALETTESETHEX / PALETTEROTATE / PALETTELOAD / PALETTESAVE` | modern | per-target palette systems differ too much |
| `TILEMAP DRAW` | modern | ugBASIC has different tilemap semantics — defer to v2 |
| `SCROLL` (zone, line, free pan) | modern | |
| `HTTP$`, `HTTPSTATUS`, `HTTPFETCH` | modern | no network on retro |
| `BUFFERNEW / BUFFERFETCH / BUFFERFREE / BUFFERLEN / BUFFERPATH$` | modern | |
| `MAPLOAD / MAPSAVE / OBJLOAD / OBJSAVE` | modern | no JSON parser on 64K |
| `LOADSOUND / PLAYSOUND / LOADMUSIC / PLAYMUSIC / ...` | modern | each target has unique audio chip |
| `MOUSESET / GETMOUSEX / GETMOUSEY / ISMOUSEBUTTON*` | modern | most retro targets have no mouse |
| `IMAGE DRAW`, `SPRITE STAMP`, `SCREENCODES`, `KEYPRESS` (rising-edge), `ANIMFRAME` | modern initially | could move to portable in v2 if ugBASIC equivalent identified |
| `ARGC`, `ARG$`, `SYSTEM`, `EXEC$`, `ENV$` | modern | shell concepts |
| `FILEEXISTS`, `OPEN`, `PRINT#`, `INPUT#`, `GETBYTE`, `PUTBYTE`, `CLOSE` | modern initially | filesystem story varies (cassette vs disk) — could narrow to a subset later |
| `TIMER` | modern | per-target timer chips differ |
| `EVAL`, `JSON$`, `JSONLEN`, `JSONKEY$` | modern | no JSON / eval in 64K |
| `DOWNLOAD`, `DIR$`, `CHDIR`, `CWD$` | modern | filesystem |
| `PEEK / POKE / MEMSET / MEMCPY` | tier-conditional | portable on retro (real hardware addresses), but values + addresses are target-specific. Linter warns; transpiler emits target-specific code or refuses. |

**Tier-conditional** is a third state for things that work everywhere but with different semantics — emit a warning, not a hard error.

## 5. File-level directives

```basic
#OPTION tier portable     ' file claims to be portable; linter strict-mode
#OPTION target c64        ' optional hint for transpiler / asset selection
```

```basic
SPRITE LOAD 0, "ship.png"

#IF MODERN
SCREEN 4
LOADSCREEN "panorama.png"
COLORRGB 255, 200, 0
FILLCIRCLE 320, 200, 80
#END IF

#IF RETRO
SCREEN 1
COLOR 7
FILLCIRCLE 160, 100, 30
#END IF

' code from here on runs on both
```

Linter / transpiler honours `#IF` / `#END IF` based on `--tier` flag — only the matching branch is validated / emitted. Block form only; no `#ELSE IF`. Keeps the preprocessor simple.

`#INCLUDE "core.bas"` is already part of rgc-basic and works the same way for portable code — the linter / transpiler walks includes recursively.

## 6. Architecture — shared infra

```
tools/rgc_lint/
  tokenizer.py        # rgc-basic-aware lex; strips comments / strings; line+col tracking
  rules.json          # statement/intrinsic → portability tier
  rules.py            # rules loader + parameter-aware checks (e.g. SCREEN n)
  walker.py           # iterates tokens, applies rules, emits diagnostics
  directives.py       # #OPTION tier / #IF MODERN / #IF RETRO / #INCLUDE
  diagnostics.py      # error/warning records, formatters (text / JSON)
  cli.py              # rgc-lint CLI entry
tools/rgc_lint/__init__.py

tools/rgc2ugb/        # later — reuses tokenizer + walker + directives
  mapping.json        # rgc-basic → ugBASIC syntax mapping
  emit.py             # ugBASIC source emitter
  asset_bundler.py    # copy referenced PNGs / sample .ugb format
  cli.py              # rgc2ugb CLI entry
```

Linter and transpiler are **siblings**, not stacked layers. Both consume the same tokenizer + walker. Linter emits diagnostics; transpiler emits ugBASIC source.

## 7. Linter — outputs

### Text mode (default)

```
$ rgc-lint --tier=portable rpg.bas
rpg.bas:23:1: error: SCREEN 4 not portable (RGBA-only) — use SCREEN 1
   23 | SCREEN 4
      | ^^^^^^^^
rpg.bas:35:3: error: OVERLAY ON not portable — see graphics-raylib.md HUD section
   35 |   OVERLAY ON
      |   ^^^^^^^^^^
rpg.bas:142:1: error: BUFFERFETCH not portable — network not available on retro targets
  142 | BUFFERFETCH 0, "https://api.example.com"
      | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

3 errors, 0 warnings
```

### JSON mode (for IDE integration later)

```json
{
  "file": "rpg.bas",
  "tier": "portable",
  "errors": [
    { "line": 23, "col": 1, "code": "E001", "keyword": "SCREEN",
      "message": "SCREEN 4 not portable (RGBA-only) — use SCREEN 1",
      "suggestion": "SCREEN 1" }
  ],
  "warnings": []
}
```

### Exit codes

- `0` — clean
- `1` — errors found
- `2` — usage error (bad CLI args / missing file)

## 8. Transpiler — design (later)

```
$ rgc2ugb --target=c64 game.bas -o build/c64/game.ugb
$ ugbc -T c64 build/c64/game.ugb -o build/c64/game.prg
```

Or wrapped:

```
$ rgc2ugb --target=c64 game.bas -o build/c64/game.prg --link
```

Per-target asset bundling: `rgc2ugb` reads referenced PNGs, copies them next to the output `.ugb`, ugBASIC compiler picks them up.

Mapping table sketch (excerpt of `mapping.json`):

```json
{
  "SCREEN 0":          "REM (text mode default)",
  "SCREEN 1":          "BITMAP ENABLE(16)",
  "SPRITE LOAD <slot>, <path> [, <tw>, <th>]":
                       "_sprimg_<slot> = LOAD IMAGE(<path>){FRAME SIZE (<tw>,<th>)}\n_sprite_<slot> = SPRITE(_sprimg_<slot>)\nSPRITE _sprite_<slot> ENABLE",
  "SPRITE DRAW <slot>, <x>, <y>":
                       "SPRITE _sprite_<slot> AT <x>, <y>",
  "VSYNC":             "WAIT VBL",
  "SLEEP <n>":         "WAIT <n*16> MS",
  "INKEY$()":          "INKEY$()",
  "KEYDOWN(<code>)":   "KEY STATE(<code>)"
}
```

Each pattern uses placeholders (`<slot>`, `<x>`); emit walks the parsed AST, substitutes parameters, optionally bundles auxiliary statements.

## 9. CI integration

```makefile
lint:
	python3 tools/rgc_lint/cli.py --tier=portable tests/portable/*.bas examples/portable/*.bas
	@echo "==> portable corpus lints clean"

check: $(TARGET) gfx_video_test lint
	...
```

`make lint` runs separately from `make check` initially; once stable, merged in. CI workflow `.github/workflows/ci.yml` adds a step.

Linter test corpus:
- `tests/portable/*.bas` — must lint clean on `--tier=portable`.
- `tests/non-portable/*.bas` — each must produce a specific expected error.

Test harness uses a small shell wrapper that compares stderr to an `.expected` snapshot per file.

## 10. Phasing

| Phase | Deliverable | Time |
|---|---|---|
| **0** | This spec doc + initial rules.json (~120 entries) | done — 2 hours |
| **1 — MVP linter** | tokenizer.py + rules.py + walker.py + cli.py + 10 portable + 10 non-portable test cases + `make lint` target | 3-4 days |
| **2 — directives** | `#OPTION tier portable` + `#IF MODERN/RETRO` + `#INCLUDE` recursion | 1-2 days |
| **3 — IDE integration** | JSON output mode + IDE save-gate (warn but allow) + linter results panel | 1 week |
| **4 — transpiler MVP** | rgc2ugb.py covering the portable subset, mapping ~50 statements, single C64 target | 1-2 weeks |
| **5 — multi-target** | Atari 8-bit, Amstrad CPC, MSX, BBC Master, Spectrum target builds + asset bundling | 1 week |
| **6 — polish** | Per-target sample roguelike, tutorial chapter, troubleshooting docs | 1 week |

Total to first compilable C64 binary from rgc-basic source: **~3-4 weeks part-time**.

## 11. Out of scope (defer to v2)

- Floating-point math (ugBASIC is integer-only by design — would need BCD or fixed-point lib).
- Multi-line FUNCTION bodies that use rgc-basic-only intrinsics (e.g. RGBA helpers) inside `#IF MODERN` blocks within the function. Linter will need to walk into function bodies for this.
- Conditional asset selection (`character_modern.png` vs `character_c64.png`) — for v1, author uses `#IF MODERN` to swap `SPRITE LOAD` paths.
- Linter rewriter (`rgc-lint --fix`) that auto-suggests portable alternatives.
- Per-target capability flags (e.g. "C64 has 8 sprites max — error if program uses slot 9 with target=c64"). Useful but a v3 polish.

## 12. Open questions

1. **Function semantics**: rgc-basic's `RETURN expr` with mid-body returns vs ugBASIC's `PROCEDURE` value-return semantics — do they round-trip cleanly? Need a small test program.
2. **String storage**: rgc-basic strings can grow up to `#OPTION maxstr` (default 4 KB). ugBASIC dynamic strings have target-dependent caps (often 256 chars). Linter should warn on `#OPTION maxstr > 255` when tier is portable.
3. **Array dimensions**: ugBASIC arrays — what's the max? Need to read ugBASIC manual. Linter could warn on `DIM A(N, M)` when N*M > target memory.
4. **Sprite slot count**: rgc-basic supports 64 slots; C64 has 8 hardware sprites. Linter warns on slot >= 8 for retro targets that lack software sprite multiplexing.
5. **PNG palette quantisation**: who reduces a 24-bit PNG to the target's 16-colour palette? Author? Transpiler? Build pipeline?

These get answered as Phase 4 (transpiler) gets exercised.

## 13. See also

- [ugBASIC user manual](https://ugbasic.iwashere.eu/manual)
- [ugBASIC reference](https://ugbasic.iwashere.eu/docs/reference/)
- [`docs/rgc-basic` retrodocs](https://docs.retrogamecoders.com/basic/rgc-basic/) — full rgc-basic surface (linter is the inverse — what survives the cut)
- `tests/portable/` — corpus of rgc-basic-portable programs
