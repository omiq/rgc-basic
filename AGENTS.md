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
    codes-replaced.bas|locate.bas|get_input_loop.bas|get_while_test.bas|kbuffer.bas|border_option_test.bas|gfx_title_test.bas) continue ;;
    meta_include_dup_line.bas|meta_include_dup_label.bas|meta_include_circular_a.bas|meta_include_circular_b.bas) continue ;;
    load_into_test.bas|memset_memcpy_test.bas) continue ;;  # GFX-only
  esac
  ./basic -petscii "$t" >/dev/null
done
```

**Shell test scripts**: `sh tests/40col_test.sh` and `sh tests/petscii_plain_output_test.sh` (requires `xxd` and `python3`).

**Trek demo** (interactive, piped): `sh tests/trek_test.sh` — runs `examples/trek.bas` with `tests/trek.txt` plus `xxx` and `no` appended (resign and don't restart).

**IF AND/OR THEN**: `tests/if_and_or_then_test.bas` — regression test for `IF X=13 AND Y=0 THEN` (trek.bas line 5930 pattern); ensures AND/OR in conditions are not parsed as bitwise.

**GFX unit test**: `./gfx_video_test` (headless, no display needed).

**Browser / WASM** (**emsdk** `emcc`, not distro `apt` emscripten — CI clones emsdk and `install latest`) + Playwright: `make basic-wasm` then `pip install -r tests/requirements-wasm.txt`, `python3 -m playwright install chromium`, then `make wasm-test` (or `python3 tests/wasm_browser_test.py`). **Canvas PETSCII**: `make basic-wasm-canvas` and `make wasm-canvas-test` (or `python3 tests/wasm_browser_canvas_test.py`). Same WASM jobs run in **tag** and **nightly** GitHub Actions. Demos use **Asyncify**; **INPUT** is inline, **GET**/**INKEY$** use **`wasm_push_key`** (terminal: focus output panel; canvas: focus canvas).

**Canvas WASM** (PETSCII 40×25, GfxVideoState): `make basic-wasm-canvas` produces `web/basic-canvas.js` + `basic-canvas.wasm`; open **`web/canvas.html`**. **INPUT**/**GET** type on the **canvas** (focus it first); keys go to a **heap ring** (see `canvas.html`). Headless regression: **`make wasm-canvas-test`** (`tests/wasm_browser_canvas_test.py`). Sprites are stubbed; use **`basic_load_and_run_gfx`** and **`wasm_gfx_render_rgba`** (see `canvas.html`).

### Caveats

- Several example programs (`dartmouth.bas`, `guess.bas`, `adventure.bas`, `get-input.bas`, `test_get.bas`) and test files (`codes-replaced.bas`, `locate.bas`, `kbuffer.bas`) require interactive or piped keyboard input — skip these in automated runs.
- The `petscii_plain_output_test.sh` has a pre-existing failure on the `feature/raylib-gfx` branch; this is not an environment issue.
- `xxd` may not be pre-installed; it is needed by `tests/40col_test.sh`. Install via `sudo apt-get install -y xxd` if missing.
