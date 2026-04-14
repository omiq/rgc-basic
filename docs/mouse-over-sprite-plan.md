# Mouse-over-sprite hit test + drag-and-drop

## Problem

Sprites are the natural building block for UI in RGC-BASIC games: unit
icons in an RTS, inventory items in an RPG, menu buttons, map tokens.
Today the programmer has all the pieces to hit-test them manually —
`GETMOUSEX()`, `GETMOUSEY()`, `SPRITEW(slot)`, `SPRITEH(slot)`, and the
`(x, y)` passed to `DRAWSPRITE` — but stitching those into a
"mouse-over this sprite right now?" check takes enough boilerplate that
tutorial programs are fiddly and drag-and-drop is harder than it
should be.

## Goal

Make `IF ISMOUSEOVERSPRITE(slot) THEN …` a one-liner, so that:

```basic
REM RTS unit select
IF ISMOUSEOVERSPRITE(UNIT) AND ISMOUSEBUTTONPRESSED(0) THEN SELECTED = UNIT

REM RPG inventory drag-and-drop
IF ISMOUSEOVERSPRITE(ITEM) AND ISMOUSEBUTTONPRESSED(0) THEN DRAGGING = ITEM
IF DRAGGING > 0 AND ISMOUSEBUTTONDOWN(0) THEN
  DRAWSPRITE DRAGGING, GETMOUSEX() - 16, GETMOUSEY() - 16
ENDIF
IF DRAGGING > 0 AND ISMOUSEBUTTONRELEASED(0) THEN DRAGGING = 0

REM Menu buttons
IF ISMOUSEOVERSPRITE(BTN_START) AND ISMOUSEBUTTONPRESSED(0) THEN GOSUB START_GAME
```

falls out naturally from the existing mouse + sprite APIs.

## What BASIC can already do today

A user-space helper covers the 80% bounding-box case with no engine
changes:

```basic
FUNCTION MOUSEOVER(sx, sy, sw, sh)
  LET MX = GETMOUSEX()
  LET MY = GETMOUSEY()
  RETURN MX >= sx AND MX < sx + sw AND MY >= sy AND MY < sy + sh
END FUNCTION

REM usage
DRAWSPRITE BTN, 120, 80
IF MOUSEOVER(120, 80, SPRITEW(BTN), SPRITEH(BTN)) AND ISMOUSEBUTTONPRESSED(0) THEN ...
```

This is the pattern we recommend in the README today. It's enough for
square sprites, fixed-layout menus, and any UI where the program
already knows where it drew each sprite. The engine function below
earns its keep for the cases the helper can't reach cleanly.

## What an engine function adds

Three things a pure-BASIC helper can't do well:

1. **Remember the sprite's current on-screen position** without the
   program tracking it in parallel variables. `DRAWSPRITE` already
   writes the slot's position into the engine's draw queue; the engine
   can expose it back.

2. **Per-pixel alpha hit testing.** A circular button on a
   transparent PNG has a rectangular bounding box but shouldn't fire
   on the transparent corners. The engine has the RGBA pixels; BASIC
   doesn't. Optional `pixel_perfect` argument gates this.

3. **Consistency with `SCROLL`, `SPRITECOLLIDE`, and tile sheets.**
   If `SPRITECOLLIDE(a, b)` respects scroll offsets and
   `DRAWSPRITETILE` cell dimensions, the mouse hit test should too,
   using the same rules. Keeping that logic in the engine means
   programs don't each reimplement it slightly differently.

## Proposed API

```basic
ISMOUSEOVERSPRITE(slot)                REM returns 1 / 0
ISMOUSEOVERSPRITE(slot, pixel_perfect) REM optional alpha-aware mode

SPRITEAT(x, y)                         REM returns topmost slot under
                                       REM point, or -1 if nothing;
                                       REM companion for "click on a
                                       REM pile" use cases
```

**`ISMOUSEOVERSPRITE(slot)`** — returns 1 if the mouse pointer is
inside the given slot's current drawn bounding rectangle, else 0.
The slot must be visible (`SPRITEVISIBLE` on), loaded, and have been
drawn at least once since load. Invisible or never-drawn slots
return 0.

**`ISMOUSEOVERSPRITE(slot, 1)`** — same, but samples the sprite's
alpha channel at `(mx - last_x, my - last_y)` and returns 1 only on
non-transparent pixels. Threshold is `alpha > 0` (or a small cutoff
like 16 to ignore dust from PNG edge softening — choose during
implementation and document).

**`SPRITEAT(x, y)`** — returns the highest-Z visible slot whose
bounding rect contains the point, or −1. Useful for "click to select
from a stack" without the program iterating. Pixel-perfect variant
can follow later if needed.

## Implementation sketch

### Tracking last-drawn positions

`gfx_sprite_enqueue_draw(slot, x, y, z, sx, sy, sw, sh)` in
`gfx/gfx_raylib.c` pushes onto a producer/consumer queue consumed by
the render thread. Reading position back from the queue is racy — the
draw may or may not have been processed yet.

**Approach:** mirror the position into an interpreter-thread-local
per-slot cache at the moment of enqueue. Small struct on
`GfxVideoState` (or a sibling static since sprites already have
their own state outside `GfxVideoState`):

```c
typedef struct {
    float x, y;        /* last enqueued top-left */
    int   z;           /* last enqueued z */
    int   w, h;        /* effective drawn size (sw/sh after tile resolve) */
    int   has_draw;    /* 0 until first enqueue */
} SpriteDrawPos;

static SpriteDrawPos g_sprite_draw_pos[GFX_SPRITE_MAX_SLOTS];
```

Update in `statement_drawsprite` / `statement_drawspritetile` after
`gfx_sprite_effective_source_rect` has resolved the effective `sw,sh`.
Read in the new `fn_ismouseoverspritse` handler. No mutex needed —
both writes and reads happen on the interpreter thread.

### Bounding-rect hit test

```c
int is_mouse_over_sprite_rect(int slot) {
    SpriteDrawPos *d = &g_sprite_draw_pos[slot];
    int mx, my;
    if (slot < 0 || slot >= GFX_SPRITE_MAX_SLOTS) return 0;
    if (!d->has_draw) return 0;
    if (!gfx_sprite_is_visible(slot)) return 0;
    mx = gfx_mouse_x();          /* already accounts for viewport scale */
    my = gfx_mouse_y();
    return (mx >= (int)d->x && mx < (int)d->x + d->w &&
            my >= (int)d->y && my < (int)d->y + d->h);
}
```

### Pixel-perfect mode

Requires reading a single texel from the sprite's source image. The
engine keeps the decoded RGBA buffer around already (used by
`DRAWSPRITE` itself). Sample at `(mx - x, my - y)` inside the slot's
current tile/crop rect, return 1 iff alpha > threshold.

Edge case: `DRAWSPRITE` with destination `sw,sh` different from
source `srcw,srch` scales the sprite. Alpha-sample must invert the
scale: `src_u = (mx - x) * srcw / dw`. Document that in the code.

### Interaction with `SCROLL`

`SCROLL` offsets the composited output by `scroll_x, scroll_y` pixels.
`GETMOUSEX()/GETMOUSEY()` return raw framebuffer coords;
`DRAWSPRITE` positions are pre-scroll world coords. Hit test must
transform one into the other:

```c
int world_mx = mx + gfx_vs->scroll_x;
int world_my = my + gfx_vs->scroll_y;
```

Document the convention: **sprite positions are in world space;
mouse coords are in screen space; hit test adjusts.** This matches
how `SPRITECOLLIDE(a, b)` works internally and keeps all three APIs
consistent.

## BASIC-level registration

Keyword in the statement/function dispatch:

- `ISMOUSEOVERSPRITE` — add to reserved words, `eval_factor`
  allow-list, and the `fn_` opcode table alongside `FN_GETMOUSEX/Y`
  and `FN_ISMOUSEBUTTON*`.
- `SPRITEAT` — same; returns a signed integer slot index (−1 for no
  hit).

Non-gfx-build fallback: parse-and-discard args, return 0 / −1, no
runtime error. Keeps `IF ISMOUSEOVERSPRITE(s) THEN x = 1 : y = 2`
composing cleanly on the terminal build (consistent with the audit
item already parked in to-do for sprite/sound statement bodies).

## Tests

C-level: not straightforward because the sprite subsystem is in
`gfx_raylib.c` behind the draw queue. Keep coverage at the BASIC
level:

- `examples/gfx_mouse_button_demo.bas` — four sprite buttons, reports
  which one the mouse is over; `ISMOUSEBUTTONPRESSED(0)` triggers a
  label change. Tutorial-ready.
- `examples/gfx_drag_and_drop_demo.bas` — three draggable tiles
  snapping to a grid on release. Shows the full select / drag / drop
  cycle.
- `examples/gfx_sprite_at_demo.bas` — three overlapping sprites in a
  stack; `SPRITEAT(GETMOUSEX(), GETMOUSEY())` reports the topmost.

Canvas WASM parity for all three — same `ISMOUSEOVERSPRITE`
implementation, since it runs on the interpreter thread and doesn't
touch the GPU side.

## Open questions

1. **Coordinate space for pixel-perfect alpha.** Source-rect sample
   vs destination-rect sample — destination is simpler but samples
   scaled pixels (OK for nearest-neighbour; wrong for bilinear if
   we ever add it). Pick source-rect for future-proofing.

2. **Threshold for alpha cutoff.** `> 0` is purist but PNG edge
   antialiasing leaves dust that triggers hits on almost-invisible
   pixels. `> 16` or `> 32` is more forgiving. Pick during
   implementation; expose as `ISMOUSEOVERSPRITE(slot, alpha_cutoff)`
   if tuning turns out to matter, default `1` = bounding, `n > 1` =
   pixel-perfect with that cutoff.

3. **Does `SPRITEAT` include transformed sprites?** If a future
   rotate/scale transform lands, the bounding rect stops being
   axis-aligned. Leave `SPRITEAT` as axis-aligned bounding only for
   MVP; revisit when sprites gain rotation.

4. **Last-drawn persistence across frames.** If a program draws a
   sprite on frame N but not frame N+1, does `ISMOUSEOVERSPRITE` on
   frame N+1 still hit the old position? Proposal: yes for one frame
   (matches user intuition that "invisible but hovered" is fine
   briefly), but `SPRITEVISIBLE slot, 0` forces a false immediately.
   Clear the `has_draw` flag on `UNLOADSPRITE`.

## Sequence

1. Add `g_sprite_draw_pos[]` and hook `statement_drawsprite` /
   `statement_drawspritetile` to update it after crop resolution.
2. Implement `fn_ismouseoverspritse` (bounding-rect mode) + wire the
   keyword. Ship with `gfx_mouse_button_demo.bas`.
3. Add pixel-perfect mode (alpha sample).
4. Implement `SPRITEAT(x, y)` as an iteration over
   `g_sprite_draw_pos[]` sorted by `z` desc. Ship with
   `gfx_sprite_at_demo.bas`.
5. Drag-and-drop example (`gfx_drag_and_drop_demo.bas`) — pure BASIC,
   no new engine work, exercises the whole loop.
6. Canvas WASM parity check — should be automatic because the hit
   test runs on the interpreter thread; add a Playwright smoke
   anyway.
