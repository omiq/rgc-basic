# AGENTS.md

## Cursor Cloud specific instructions

### Overview

**RGC-BASIC** (Retro Game Coders BASIC) is a modern cross-platform BASIC interpreter with classic (Commodore-style) syntax compatibility, written in C. It compiles to a single `basic` binary with zero runtime dependencies beyond the C standard library and POSIX math (`-lm`).

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

**Browser / WASM** (**emsdk** `emcc`, not distro `apt` emscripten — CI clones emsdk and `install latest`) + Playwright: `make basic-wasm` then `pip install -r tests/requirements-wasm.txt`, `python3 -m playwright install chromium`, then `make wasm-test` (or `python3 tests/wasm_browser_test.py`). **Canvas PETSCII**: `make basic-wasm-canvas` and `make wasm-canvas-test` (or `python3 tests/wasm_browser_canvas_test.py`). **Charset lower regression** (mixed-case + `CHR$(32)` / `CHR$(65)`, PETSCII on/off): **`make wasm-canvas-charset-test`** (`tests/wasm_canvas_charset_test.py`). **Tutorial embeds**: `make basic-wasm-modular` and `make wasm-tutorial-test` (`tests/wasm_tutorial_embed_test.py`); see **`docs/tutorial-embedding.md`**. WASM Playwright suite also runs on **push to `main`** (`.github/workflows/wasm-tests.yml`) and in **tag** release WASM job. Demos use **Asyncify**; **INPUT** is inline, **GET**/**INKEY$** use **`wasm_push_key`** (terminal: focus output panel; canvas: focus canvas). **Pause**/**Resume** use **`Module.wasmPaused`** on both **`index.html`** and **`canvas.html`**; **Stop** uses **`wasmStopRequested`**.

**Canvas WASM** (PETSCII 40×25, GfxVideoState, bitmap + PNG sprites): `make basic-wasm-canvas` produces `web/basic-canvas.js` + `basic-canvas.wasm`; open **`web/canvas.html`**. **INPUT**/**GET** type on the **canvas** (focus it first). Headless: **`make wasm-canvas-test`**, **`make wasm-canvas-charset-test`**. Use **`basic_load_and_run_gfx`** and the RGBA refresh path (see `canvas.html`).

### Caveats

- Several example programs (`dartmouth.bas`, `guess.bas`, `adventure.bas`, `get-input.bas`, `test_get.bas`) and test files (`codes-replaced.bas`, `locate.bas`, `kbuffer.bas`) require interactive or piped keyboard input — skip these in automated runs.
- The `petscii_plain_output_test.sh` has a pre-existing failure on the `feature/raylib-gfx` branch; this is not an environment issue.
- `xxd` may not be pre-installed; it is needed by `tests/40col_test.sh`. Install via `sudo apt-get install -y xxd` if missing.
