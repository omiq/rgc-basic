# RGC-BASIC examples

Runnable demos and tutorial programs. From the repo root, most terminal examples run as:

```sh
make
./basic -petscii examples/yourprogram.bas
```

Use `make basic-gfx` and `./basic-gfx` for Raylib graphical examples (needs a display).

## Super Star Trek (`trek-new.bas`)

Structured, label-free port of Mike Mayfield’s **Super Star Trek** (1974), kept for teaching modern RGC-BASIC: `FUNCTION` handlers, `SELECT CASE` state dispatch, `EXIT`/`CONTINUE`, no `GOTO` between routines.

Classic line-number version: `trek.bas`. Smoke test for that build: `sh tests/trek_test.sh`.

### Reading order (source tour)

Read the `.bas` file in this order the first time through:

1. **Constants and data** (top): state IDs (`ST_*`), sector tokens, `DIM` / `COURSE_VEC` / `DEVICE_DAMAGE`, `DEF FND` / `DEF FNR`.
2. **Main loop** (`DO` / `SELECT CASE GameState`): dispatches to state functions until `ST_QUIT`.
3. **`SetupGame()`** — title, galaxy generation (`G` packing with `K3`/`B3` per quadrant), mission briefing.
4. **`EnterQuadrant()`** — decode current quadrant, place Enterprise / Klingons / base / stars, then short scan.
5. **`DoCommand()`** — energy check, command prompt, `SELECT CASE CMD` to handlers.
6. **Command handlers** — `Nav`, `ShortRangeScan`, `Lrs`, `Phasers`, `Torpedo`, `Shields`, `Damage`, `Computer` (+ computer sub-functions).
7. **Combat / movement helpers** — `KlingonsFire`, `ManeuverEnergy`, `FindEmpty`, `PlaceToken`, `CheckSector`.
8. **End states** — `ShipDestroyed`, `ShowVictory`, `ShowMissionEnd`, `AskPlayAgain`, etc.
9. **I/O utilities** — `GetInput`, `Pause`, `ShowKey`, `ShowCommands`, `QuadrantName`.

Galaxy cell encoding: `G(quadrant) = K3*100 + B3*10 + stars` (see the decode comment in `EnterQuadrant()`).

### Source style (`trek-new.bas`)

Tutorial readability convention (not required for other examples):

- **Built-ins** lower case: `print`, `if`, `for`, `function`, `select case`, `return`, …
- **Game state / arrays** upper case: `SHIP_ENERGY`, `QUADRANT_X`, `COURSE_VEC`, …
- **Your routines** PascalCase: `SetupGame()`, `DoCommand()`, `ShortRangeScan()`, …
- **Player-facing strings** upper case inside literals (classic trek voice)

Re-apply built-in lowercasing after large edits:

```sh
python3 tools/lowercase_builtin_keywords.py examples/trek-new.bas
```

### Deterministic regression

Refactors should not change gameplay output for fixed input. From repo root:

```sh
make
sh tests/trek_new_regression.sh
```

Three piped scenarios live under `tests/fixtures/trek_new/`:

| Scenario | Input file | Exercises (briefly) |
|----------|------------|---------------------|
| A | `input_A.txt` | SRS/LRS, computer modes, damage report, warp, galaxy map |
| B | `input_B.txt` | Play-again restart (`aye` then `xxx` / `no`) |
| C | `input_C.txt` | Warp, phasers, torpedo hits, damage |

The harness copies the program to a temp file with `RND(-1)` and `RND(-TI)` replaced by `RND(1)` so output is stable across machines. Goldens are `golden_A.txt`, `golden_B.txt`, `golden_C.txt` (PETSCII terminal bytes).

After an intentional output change:

```sh
UPDATE_GOLDEN=1 sh tests/trek_new_regression.sh
```

Review the `git diff` on `tests/fixtures/trek_new/golden_*.txt` before committing.

Lint (modern tier):

```sh
python3 -m tools.rgc_lint.cli --tier=modern examples/trek-new.bas
```
