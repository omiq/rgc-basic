# Transpiler examples

Proof programs for the RGC-BASIC -> C transpiler (`../emit_c.py`). All build, from one
`.bas`, for C64/cc65 + CoCo3/cmoc (+ Z80/sdcc compile).

- **`tier1.bas`** — Tier-1: `CLS`, `TEXTAT x,y,s`, `FOR..TO..[STEP]`/`NEXT`, int var.
  Draws a 10-wide `#` wall + `@`, then ends (returns to READY/OS — faithful BASIC, the
  transpiler injects no clear/pause/hold).
- **`procgen.bas`** — Tier-2: `DIM` 2D array, nested `FOR`, `IF`/relational, `RND(n)`.
  Generates a bordered 16×8 map with random interior walls. Deterministic (fixed seed +
  shared xorshift16) → identical map on every target.
- **`move.bas`** — strings + input: string vars (`K$`), `GET` (non-blocking char),
  `WHILE`/`WEND`, `UCASE$`-normalised key compares. Move an `@` with WASD; `q`/`Q` quits.
- **`strings.bas`** — string functions: `UCASE$`/`LEFT$`/`MID$`/`LEN`/`CHR$`. Renders
  `HELLO` / `hel` / `ell` / `FIVE` / `A`.

The headline proof is **`../../../examples/trek-portable.bas`** (not in this dir) — a full
playable Star Trek, modern-tier (`SELECT CASE`, `DICT`, `COLOR`, `PRINT TAB`, scrolling
console). Transpiles + compiles warning-clean on cc65 (6502) / cmoc (6809) / sdcc (Z80) /
native, and plays like the interpreter. ~1900 lines of emitted C. Use it as the stress test
when the small proofs above pass but you want to exercise the whole emitter.

## Check transpilability

`python3 -m tools.rgc_lint.cli --check-transpile --tier=modern <file>.bas` runs the actual
emitter and reports the first construct that can't transpile to C (`T001`) — the linter and
transpiler share one parser (`expr.py`) + emitter, so the lint answer matches reality.
(`--check-transpile` suppresses tier-membership errors — the C emitter supports the whole
`modern` tier — so `--tier=portable` answers the same yes/no; `modern` just stops the noise
on modern-tier programs like `trek-portable.bas`.)

Full design: `../../../docs/basic-to-c-transpiler-plan.md` (§ Text-game tier).

## Emit C

```sh
mkdir -p /tmp/rgcb   # a CLEAN dir — see gotcha below
python3 -m tools.rgc_lint.emit_c tools/rgc_lint/examples/tier1.bas > /tmp/rgcb/tier1.c
```

> **Gotcha:** emit into a directory that has NO `platform.h` of its own. cmoc (and gcc)
> search the source file's own directory for `#include "platform.h"` *before* `-I platform`,
> so a stray stub `platform.h` next to the emitted `.c` gets picked up instead of retro-c's
> real one and the build explodes. cc65 does not search the source dir, which is why C64
> tolerated it but CoCo3 didn't.

The emitted `.c` is `game`-shaped: `#include "platform.h"`, a `main()` that calls
`plat_init()` then the body. It compiles against retro-c's `platform.h` contract
(`plat_cls` / `plat_puts` already exist on every adapter — no contract change needed).

## Build for a real target

These build against the retro-c adapters. Run from the **retro-c repo root**
(`~/github/retro-c`), with the emitted `.c` swapped in for the game sources — same
flags as `build/Makefile.<target>`, minus `$(GAME_SOURCES)`.

> **Path gotcha (cross-repo build):** `platform.h`, `plat_host.c`, `plat_c64.c`, the
> `game/` dir etc. all live in **retro-c**, not in rgc-basic. The `-I platform -I game`
> and `platform/plat_*.c` arguments below are relative to the retro-c repo root, so you
> must `cd ~/github/retro-c` first. The emitted `.c` itself can live anywhere — pass it by
> absolute path (e.g. `~/github/rgc-basic/build/.../trek.c`). Building from inside
> rgc-basic fails with `no such file or directory: 'platform/plat_host.c'` because those
> adapters aren't in this repo.

### Native (host) — fastest self-test, no emulator

The quickest way to confirm an emitted program actually *runs*: build against the
ncurses host adapter (`plat_host.c`) and play it in any terminal.

```sh
cc -std=c89 -I platform -I game \
  -o /tmp/trek-native /tmp/rgcb/trek-portable.c platform/plat_host.c -lncurses
/tmp/trek-native   # interactive ncurses — run in a real terminal, not piped
```

No `-I runtime` needed: `rgc_real.h` is inlined into the emitted `.c`. `plat_host.c`
links against `-lncurses` (`initscr`/`cbreak`/`getmaxy`…); without it the compile
succeeds but the link fails with undefined ncurses symbols.

### C64 (cc65) — verified working in VICE 2026-06-16

```sh
cl65 -t c64 -O -Cl -I platform -I game \
  -o /tmp/tier1-c64.prg /tmp/rgcb/tier1.c platform/plat_c64.c
x64sc /tmp/tier1-c64.prg
```

### CoCo3 (cmoc)

```sh
cmoc --coco -O2 -I build/cmoc-shim -I platform -I game \
  -o /tmp/tier1-coco.bin /tmp/rgcb/tier1.c platform/plat_coco3.c
# run (needs xroar + coco3.rom; see build/Makefile.coco):
xroar -rompath ../8bitworkshop/xroar -default-machine coco3 -run /tmp/tier1-coco.bin
```

(Swap `tier1.c` for `procgen.c` / `move.c` in the build lines above for the other demos.)

## Notes

- No `COL_DEFAULT` in `platform.h` (colours are 0-7); the emitter uses `COL_WHITE`.
  Mono targets (CoCo/Dragon VDG, MSX SCREEN 1) ignore colour anyway.
- **RND:** `RND(n)` → `plat_rand() % n` (0..n-1 integer). The emitter auto-seeds with a
  fixed **non-zero** constant (`plat_seed_rand(1)`) — `plat_seed_rand(0)` is the contract's
  sentinel for *hardware entropy* (non-deterministic). Adapters share an xorshift16 PRNG, so
  the same seed gives the same sequence everywhere.
- **No libc headers.** The emitter never emits `#include <string.h>` etc — not every retro
  toolchain ships them (cmoc doesn't). String ops use inline helpers (`rgc_scpy`, `rgc_seq`).
- **`GET`** is non-blocking (empty string if no key), via the `plat_getkey_nb` contract fn —
  implemented on the c64/coco3/host pilots only so far (other adapters: see
  `retro-c/docs/refactor-plan.md`).
- The emitter is still a deliberately dumb regex walker, **not** the eventual expression AST.
  The condition/expression handling is where it strains — that's the trigger for option B (a
  real parser shared with the linter).
