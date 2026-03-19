# AGENTS.md

## Cursor Cloud specific instructions

### Overview

CBM-BASIC is a Commodore BASIC v2-style interpreter written in C. It compiles to a single `basic` binary with zero runtime dependencies beyond the C standard library and POSIX math (`-lm`).

### Build & Run

See the `README.md` and `Makefile` for standard commands. Quick reference:

- `make` — builds the `basic` binary
- `make gfx_video_test` — builds the headless GFX video memory test
- `make clean` — removes built binaries
- `./basic <program.bas>` — runs a BASIC program
- `./basic -petscii <program.bas>` — runs with PETSCII/ANSI colour support

### Testing

**BASIC test suite** (mirrors CI): run all non-interactive `.bas` tests:
```sh
for t in tests/*.bas; do
  case "$(basename "$t")" in
    codes-replaced.bas|locate.bas) continue ;;
    meta_include_dup_line.bas|meta_include_dup_label.bas|meta_include_circular_a.bas|meta_include_circular_b.bas) continue ;;
  esac
  ./basic -petscii "$t" >/dev/null
done
```

**Shell test scripts**: `sh tests/40col_test.sh` and `sh tests/petscii_plain_output_test.sh` (requires `xxd` and `python3`).

**GFX unit test**: `./gfx_video_test` (headless, no display needed).

### Caveats

- Several example programs (`dartmouth.bas`, `guess.bas`, `adventure.bas`, `get-input.bas`, `test_get.bas`) and test files (`codes-replaced.bas`, `locate.bas`, `kbuffer.bas`) require interactive or piped keyboard input — skip these in automated runs.
- The `petscii_plain_output_test.sh` has a pre-existing failure on the `feature/raylib-gfx` branch; this is not an environment issue.
- Build produces compiler warnings for unused variables in `basic.c` — these are benign and expected on this branch.
- `xxd` may not be pre-installed; it is needed by `tests/40col_test.sh`. Install via `sudo apt-get install -y xxd` if missing.
