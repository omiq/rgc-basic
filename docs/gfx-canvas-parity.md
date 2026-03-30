# Canvas WASM parity with basic-gfx (Raylib)

The browser build `make basic-wasm-canvas` targets the same **GfxVideoState** model and BASIC surface area as `./basic-gfx`, without Raylib.

## Rendering pipeline (order matches Raylib)

1. **Base layer** — `SCREEN 0`: PETSCII grid from screen/colour/char RAM. `SCREEN 1`: 320×200 1bpp bitmap (`gfx_bitmap_get_pixel`), centred horizontally in the 320- or 640-wide framebuffer (same offset rule as `gfx_raylib.c`).
2. **Sprite layer** — After the base layer, `LOADSPRITE` / `DRAWSPRITE` / `SPRITEVISIBLE` / `UNLOADSPRITE` are applied. PNGs are decoded with **stb_image** (`gfx/stb_image.h`), queued the same way as in Raylib, then alpha-composited in **z-order** (`gfx/gfx_software_sprites.c` + `gfx_canvas_sprite_composite_rgba`).
3. **Browser chrome** — `#OPTION border` / `-gfx-border` is drawn in **`web/canvas.html`**: the WASM buffer stays **w×200** (w = 320 or 640); JS expands the `<canvas>` by `2×border` and fills the margin with the border colour (or video background if colour omitted).

## Files

| Piece | Role |
|--------|------|
| `gfx/gfx_canvas.c` | PETSCII + bitmap rasterisation; `gfx_canvas_render_full_frame` = base + sprites |
| `gfx/gfx_software_sprites.c` | PNG load from disk path, queue processing, compositing |
| `gfx/stb_image.h` | Vendored decoder (STB_IMAGE_IMPLEMENTATION only in `gfx_software_sprites.c`) |
| `basic.c` (`wasm_gfx_refresh_js`) | Calls `gfx_canvas_render_full_frame`; sets `Module.wasmGfxBorderPx`, `wasmGfxBorderColorIdx`, `wasmGfxContentBgIdx` for JS |

## Using gfx examples in the browser

1. Build: `make basic-wasm-canvas`.
2. Open `web/canvas.html` over HTTP.
3. **PNG paths** are resolved like native: relative to the **`.bas` file’s directory**. For `/program.bas`, use **`Module.FS.writeFile('/program.bas', …)`** and put assets next to it, e.g. `/hud_panel.png`, or upload via **Upload to VFS** with names matching the program (`LOADSPRITE 0,"hud_panel.png"` → file `/hud_panel.png` or `/examples/hud_panel.png` depending on path in the program).

## Differences / limits

- **`PEEK(56320 + n)` keyboard matrix** (`GFX_KEY_BASE` = `0xDC00`): **basic-gfx** fills `key_state[]` every Raylib frame. **Canvas** now mirrors the same indices from **`canvas.html`** on `keydown` / `keyup` via **`wasm_gfx_key_state_set`** / **`wasm_gfx_key_state_clear`** (letters A–Z, digits, arrows, Escape, Space, Enter, Tab). Programs like **`examples/gfx_jiffy_game_demo.bas`** that poll **`PEEK(KEYBASE+87)`** (W) work when the canvas is focused. Keys are cleared at each **Run**.

- **Performance**: software PNG decode and per-pixel composite on the main WASM thread; large sprites or many slots cost more than GPU textures in Raylib.
- **Window title**: `#OPTION gfx_title` does not rename a browser tab (no change from before).
- **Threading**: Raylib processes the sprite queue on the **main** thread while BASIC runs in a **worker** thread; WASM runs single-threaded but processes the queue whenever the framebuffer is refreshed or `SPRITEW`/`SPRITEH` runs, so loads complete before dimensions are read.

## Tests

`make wasm-canvas-test` checks **bitmap mode** (`SCREEN 1` + `PSET`), **sprite overlay** (fetch `testfixtures/red8x8.png` into MEMFS), and the **`examples/gfx_canvas_demo.bas`** program (fetch `gfx_canvas_demo.png` from the static `web/` copy into MEMFS, assert a red pixel inside the drawn sprite).

## Example program

`examples/gfx_canvas_demo.bas` — two `PRINT` lines plus `LOADSPRITE` / `DRAWSPRITE` for `gfx_canvas_demo.png` (8×8 solid red PNG, same asset as `tests/fixtures/red8x8.png`).
