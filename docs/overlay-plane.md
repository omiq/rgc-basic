# OVERLAY plane (HUD layer above the cell list)

Status: shipped 2026-04-27 (rgc-basic c9e64ff / commit dcb5b5c).
Scope: raylib renderer (basic-wasm-raylib + basic-gfx).
Canvas WASM: legacy software path is frozen — overlay writes still
land in the buffer but composite *with* the bitmap, not above it.

## Why

The raylib backend renders in three passes per frame:

1. **bitmap plane** (`bitmap_rgba` for SCREEN 2/4, indexed/text for
   the other modes) — populated by `CLS`, `PSET`, `LINE`, `RECT`,
   `FILLRECT`, `DRAWTEXT`, `IMAGE DRAW`, etc.
2. **cell list** (`g_tm_cells`) — populated by `TILEMAP DRAW` and
   `SPRITE STAMP`. Always composites *over* the bitmap plane.
3. (new) **overlay plane** (`bitmap_rgba_overlay`) — populated by
   the same bitmap-plane primitives while `OVERLAY ON` is in effect.
   Composites with `BLEND_ALPHA` over the cell list.

Before the overlay existed, anything written by `DRAWTEXT` or
`FILLRECT` lived strictly underneath every tilemap cell. A pixel-
smooth scrolling tilemap with a top status bar would happily paint
its partial top row across the HUD strip, obscuring text. Programs
that wanted Zelda-SNES-style dialog boxes — a framed text panel
floating above the world — had no clean answer; the only workaround
was to snap the camera to a tile boundary and lose smooth Y scroll.

## API

Three subcommands, no arguments:

```
OVERLAY ON     ' redirect bitmap-plane writes to the overlay
OVERLAY OFF    ' back to the main bitmap (default state)
OVERLAY CLS    ' clear overlay to fully transparent (alpha = 0)
```

`OVERLAY ON` lazy-allocates two RGBA buffers (draw + show) at the
current `rgba_w × rgba_h` dimensions. `DOUBLEBUFFER ON` flips the
overlay pair atomically with the main pair on `VSYNC`. Switching
SCREEN modes frees the overlay so the next `OVERLAY ON` rebuilds at
the new size.

While `OVERLAY ON` is in effect, every bitmap-plane primitive writes
to the overlay buffer instead of `bitmap_rgba`. That includes:

- `PSET`, `LINE`, `RECT`, `FILLRECT`, `CIRCLE`, `FILLCIRCLE`,
  `ELLIPSE`, `FILLELLIPSE`, `TRIANGLE`, `FILLTRIANGLE`, `POLYGON`,
  `FILLPOLYGON`, `FLOODFILL`
- `DRAWTEXT`, `PRINT` (when in SCREEN 2/4)
- `CLS` — clears just the overlay, **not** the cell list (otherwise
  every HUD frame would wipe the world tiles already submitted).

`COLORRGB` mutates pen state regardless of target — pen state is
shared between the two planes, since it's just `pen_r/g/b/a`.

## Idiomatic frame loop

```basic
DO
  CLS                                          ' clear world bitmap
  TILEMAP DRAW 0, 0, 0, COLS, ROWS, MAP()      ' tiles
  SPRITE STAMP 1, PX, PY, FRAME, 20            ' player

  OVERLAY ON
  CLS                                          ' clear overlay
  COLORRGB 16, 16, 16
  FILLRECT 0, 0 TO 319, 23                     ' status bar bg
  COLORRGB 255, 255, 255
  DRAWTEXT 4, 4, "LIFE 3   AREA OVERWORLD"
  IF DIALOG$ <> "" THEN
    COLORRGB 0, 0, 0
    FILLRECT 8, 28 TO 311, 52                  ' dialog frame
    COLORRGB 255, 240, 80
    DRAWTEXT 14, 36, DIALOG$
  END IF
  OVERLAY OFF

  VSYNC
LOOP
```

The status strip and dialog box always sit above the world — even
during pixel-smooth Y scrolling — because the renderer composites
the overlay last.

## Composite order (raylib)

```
target = LoadRenderTexture(...)

render_<mode>_screen(...)               ' bitmap_rgba → target
gfx_sprite_composite_range(...)         ' tilemap + sprite cells
render_rgba_overlay(...)                ' overlay_rgba → target (BLEND_ALPHA)
```

`render_rgba_overlay` is a no-op until a program calls `OVERLAY ON`
for the first time (`overlay_active` flag). Legacy programs that
never touch `OVERLAY` see exactly the prior render path.

## Implementation notes

- **State** lives in `GfxVideoState`:
  `bitmap_rgba_overlay`, `bitmap_rgba_overlay_show`, `target_overlay`,
  `overlay_active`. See `gfx/gfx_video.h`.
- **Writers** funnel through `rgba_active_draw(s)` (in
  `gfx/gfx_video.c`) which returns the overlay buffer when
  `target_overlay` is set, else the main bitmap.
- **Statement** is `statement_overlay()` in `basic.c`; dispatched
  under the `c == 'O'` block.
- **Cell-list clear** in `statement_cls` is skipped when
  `target_overlay` is on. This is the trickiest bit — without it,
  the second `CLS` in the loop above wipes the tiles + player you
  just submitted, leaving only the HUD visible.
- **Renderer hook** is `render_rgba_overlay()` in `gfx/gfx_raylib.c`,
  called after `gfx_sprite_composite_range()` on both the desktop
  service-loop path (`raylib_run`) and the Emscripten WASM path
  (`gfx_raylib_wasm_render_one`).

## Limitations

- Canvas WASM (frozen) reuses the writer redirect, but its compositor
  flattens everything onto the bitmap, so an overlay-drawn HUD ends
  up under cells the same way it did before. A canvas-side fix is
  out of scope until the canvas freeze lifts.
- Overlay dimensions track `bitmap_rgba`. If you mode-switch between
  SCREEN 2 (320×200) and SCREEN 4 (640×400) mid-program the overlay
  is freed and re-allocated — pixels from the old size are not
  preserved.
- Pen state (`COLORRGB`) is global, not per-target. Programs that
  want a different "HUD palette" should save/restore pen around the
  `OVERLAY ON … OVERLAY OFF` block themselves.
- No `z` ordering inside the overlay — it's a single bitmap, drawn
  in source-order. Layering separate HUD elements works the way
  classic CRT overlays do: paint back-to-front into the same
  buffer.

## See also

- `examples/rpg/rpg.bas` — production user. Status bar at y=0..23,
  framed dialog box at y=28..52. Both rendered every frame inside
  `RenderHud()`.
- `gfx/gfx_video.h` — state + helper prototypes.
- `gfx/gfx_video.c` — buffer alloc/free/clear, target switch.
- `gfx/gfx_raylib.c` — `render_rgba_overlay`.
- `basic.c` — `statement_overlay`, dispatch, CLS guard.
