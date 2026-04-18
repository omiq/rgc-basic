# Tilemap & sprite-sheet respec

Status: draft spec, not implemented.
Scope: graphics (basic-gfx + wasm/raylib).
Date: 2026-04-17.

## Problem

The current API blurs two distinct ideas onto one sheet concept:

1. **Animation frames** — cells that are successive poses of a single sprite
   (e.g. a chick flap cycle). The game code picks one cell at a time and
   draws it at a position.
2. **Tileset tiles** — cells that are distinct building blocks of a
   background (e.g. grass, wall, water). The game code draws many different
   cells across a grid in one frame.

Data representation is identical (a grid of equal-size cells in a PNG), but
the intent, and therefore the API, should be different. Today:

- `LOADSPRITE slot, path, cell_w, cell_h` — loads a sheet (no distinction
  between "frames" and "tiles").
- `SPRITETILES(slot)` — returns cell count. The name says "tiles" but it's
  also the frame count for animation-style use.
- `SPRITEFRAME slot, n` — sets the current animation frame for `DRAWSPRITE`.
- `DRAWSPRITETILE slot, x, y, tile_idx [,z]` — draws one cell by index.

Issues:

- `SPRITETILES` name mixes the two concepts. Reads as "how many tiles" but
  is also the frame count.
- There is no batched command to stamp a grid of tiles; each tile costs one
  interpreter call. A 40×25 background = 1000 interpreter dispatches per
  frame, which is slow on WASM.
- `DRAWSPRITETILE` is named after the "tile" intent but is still a single
  draw — indistinguishable from a sprite draw with an explicit frame.

## Goals

- Separate the two intents in the API so user code signals which it means.
- Keep the underlying loaded-cells data shared (one sheet can be used as
  either an animation strip or a tileset — don't force reload).
- Add a batched tilemap draw so a full-screen background costs one
  interpreter call regardless of tile count.
- Ship deprecation shims so existing programs keep working for one release.

## Proposed vocabulary

- **Sheet** — a loaded PNG divided into a grid of equal-size cells. This is
  the raw thing. Each sheet has `(cell_w, cell_h, cols, rows, count)`.
- **Frame** — a cell index used with a single moving sprite (animation).
- **Tile**  — a cell index used in a tilemap (background composition).

A sheet can be used as either or both. The sheet itself has no mode.

## Naming convention

Two-word verb/noun style for new graphics commands (`SPRITE LOAD`, `TILE
DRAW`, `SCREEN ZONE`, …), matching AMOS/STOS precedent. Existing concat
names (`LOADSPRITE`, `DRAWSPRITE`, …) stay as permanent aliases — both
spellings tokenise to the same opcode, no deprecation warnings, no
removal date. See naming-convention note at the top of `to-do.md`.

## API (proposed)

### Loading

- `SPRITE LOAD slot, path [,cell_w, cell_h]` (new name)
  - Alias: `LOADSPRITE` (existing; permanent).
  - With cell dims → treated as a sheet.
  - Without cell dims → single image (1×1 sheet).

### Sheet metadata (intent-named accessors)

All read the same underlying sheet record; pick the name that matches
how the caller thinks about the data.

- `SPRITE FRAMES(slot)` — total cells, read as animation-frame count.
- `TILE COUNT(slot)` — total cells, read as tileset-tile count.
  - Alias: `SPRITETILES(slot)` (existing; permanent).
- `SHEET COLS(slot)` — grid columns.
- `SHEET ROWS(slot)` — grid rows.
- `SHEET WIDTH(slot)` — cell width in pixels.
- `SHEET HEIGHT(slot)` — cell height in pixels.

Dropped from earlier draft: `SHEETCELLS(slot)`. Not intuitive — "cells"
doesn't signal whether caller wants frame count, tile count, or grid
dimensions. Replaced with the six intent-named accessors above.

### Animation (single-sprite use)

- `SPRITE FRAME slot, n` — set current animation frame.
  - Alias: `SPRITEFRAME` (existing; permanent).
- `SPRITE DRAW slot, x, y [,z]` — draw current frame.
  - Alias: `DRAWSPRITE` (existing; permanent).

Animators never reach for "tile" vocabulary.

### Tileset use (explicit single draw)

- `TILE DRAW slot, x, y, tile_idx [,z]` — canonical.
  - Alias: `DRAWTILE` / `DRAWSPRITETILE` (both permanent).
- Stateless; does not mutate `SPRITE FRAME`.

### Batched tilemap

- `TILEMAP DRAW slot, x0, y0, cols, rows, map()`
  - Alias: `DRAWTILEMAP` (permanent).
  - `map()` is a 1-D BASIC integer array of length `cols*rows`, row-major,
    tile indices. `0` = transparent (skip draw).
  - One interpreter dispatch. Runtime iterates in C and issues one batched
    GPU draw where possible (raylib: one `DrawTexturePro` per cell but
    inside C; WASM: one native loop, no asyncify overhead per tile).
  - Optional trailing `[,z]`.

Optional scroll-offset form (v2, defer):

- `TILEMAP DRAW slot, x0, y0, cols, rows, map(), src_x, src_y`
  - `src_x, src_y` shift the sample origin inside the map so the top-left
    cell reads from an offset. Smooth scrolling without rebuilding the map
    each frame.

### Viewport scroll (AMOS `Screen Offset` port)

- `SCREEN OFFSET slot, x_off, y_off`
  - Shifts the visible window inside an oversized bitmap/surface slot
    without copying data. Paired with a bitmap larger than the visible
    screen (e.g. 512+32 tall) for wrap-around scrolling.
  - Implementation: adjust the source-rect origin used when compositing
    the surface to the visible screen. No pixel movement.
  - Scope question: operates on blitter surfaces (see
    `docs/rgc-blitter-surface-spec.md`) rather than sprite/tilemap slots.
    Cross-linked but owned by blitter spec.

### Scroll zones (AMOS `Def Scroll` / `Scroll` port)

- `SCREEN ZONE zone, x1, y1, x2, y2, x_spd, y_spd`
  - Defines rectangular scroll region + per-axis velocity. Numbered
    zone handle for later reference.
- `SCREEN SCROLL zone`
  - Advances that zone one tick: moves pixels by `(x_spd, y_spd)` via
    surface blit; wraps at zone edges.

All three new scroll/viewport commands live under `SCREEN *` so the
family reads uniformly alongside the existing `SCREEN n` mode switch:

- `SCREEN OFFSET ...` — viewport shift
- `SCREEN ZONE ...` — define parallax band
- `SCREEN SCROLL ...` — tick a band

Useful for parallax (sky zone slow, ground zone fast). Implementation is
surface-blit-based; owned by blitter spec (see cross-reference below).

## Implementation notes

### basic.c

1. Tokeniser: accept both spellings for each pair. Keyword table entries
   for the two-word forms map to the same handler as the concat alias.
   No deprecation warnings.
2. New opcodes: `TILE_DRAW`, `TILEMAP_DRAW`, `SHEET_COLS`, `SHEET_ROWS`,
   `SHEET_WIDTH`, `SHEET_HEIGHT`, `SPRITE_FRAMES`, `TILE_COUNT`,
   `SCREEN_OFFSET`, `SCREEN_ZONE`, `SCREEN_SCROLL`.
3. `TILEMAP DRAW`: fetch array address + length, validate, call
   `gfx_draw_tilemap(slot, x0, y0, cols, rows, int16_t *map, map_len)`.

### gfx/gfx_raylib.c (native + wasm)

- New entry point `gfx_draw_tilemap(...)` composes the sheet texture:
  - Compute source rect per cell = `(cell_idx % cols) * cell_w`,
    `(cell_idx / cols) * cell_h`, cell_w, cell_h.
  - Destination rect = `(x0 + col*cell_w, y0 + row*cell_h, cell_w, cell_h)`.
  - Skip cell where `idx == 0`.
  - Use the same z-bucket the slot already draws into so tiles composite
    with sprites correctly.

### Performance notes

- Native: gain over per-call `TILE DRAW` loop is marginal (interpreter
  dispatch cheap on desktop). Worth it for readability.
- WASM: big win. Each interpreter statement hits the asyncify yield-point
  path (~1 µs). Drawing 1000 tiles as 1000 statements ≈ 1 ms just in
  overhead. One `TILEMAP DRAW` = one yield-point crossing.

### Alias policy (no migration)

- Two-word forms and concat forms share one opcode each. Both valid
  forever.
- Docs lead with two-word form for new material; existing docs/examples
  using concat names stay valid, no rewrite required.
- Tokeniser treats them as interchangeable at parse time.

## Relationship to other specs

- `docs/sprite-features-plan.md` — today's sprite+sheet API
  (`LOADSPRITE`/`DRAWSPRITETILE`/`SPRITETILES`/`SPRITEFRAME`) and the
  open "full world tilemap engine" bullet. This doc is the detailed plan
  for that bullet. The sprite doc should link here once merged.
- `docs/rgc-blitter-surface-spec.md` — AMOS/STOS-style CPU **`IMAGE COPY`**
  between bitmap surfaces. Complementary, not redundant:
  - Blitter path: stamp tiles **once** into an off-screen bitmap, then
    `IMAGE COPY` the region onto the visible bitmap every frame.
    Good for static backgrounds; zero per-frame tile overhead.
  - `DRAWTILEMAP` path (this doc): re-issue the tile grid on the GPU
    every frame. Good for smooth scrolling, animated tiles, dynamic
    damage maps. No surface allocation or pre-pass required.
  - Expect both to ship. Game code picks based on whether the map is
    static or changing.
- `docs/screen-modes-plan.md` — tile dims (`cell_w`/`cell_h`) are
  independent of the current `SCREEN` mode. `DRAWTILEMAP` must work in
  all bitmap-capable modes; spec's cols/rows are in the tilemap, not in
  screen character cells.
- `to-do.md` items 4 (per-layer stack) and 5 (world tile grid storage) —
  both partially addressed here. Multi-layer stacking is left to a
  future `DRAWTILEMAP` call per layer (caller-managed z), not an
  implicit stack.

## AMOS precedent

AMOS BASIC (Amiga, early 90s) solved the same problems. Their vocabulary is
worth reading before locking ours down because it already covers the two
render paths and the scroll mechanics we need. Source: Chris Garrett,
"AMOS BASIC — Better Scrolling", retrogamecoders.com.

### Two render paths, two command families

- `Bob bob, x, y, frame` — "blitter object". Drawn **into** the bitmap via
  the Amiga blitter. CPU/RAM path. Erases and re-stamps each frame.
- `Sprite n, x, y, frame` — **hardware overlay** layer above the bitmap.
  "Sprites are on a layer above the regular viewable screen so are much
  easier". Cheap movement, limited count.
- `Paste Bob x, y, frame` — stamp a Bob permanently into the bitmap (no
  auto-erase). Good for scenery.
- `Paste Icon x, y, tile_num` — stamp a tile from the loaded artwork bank
  at a specific bitmap location. AMOS's `DRAWTILE` equivalent.

rgc-basic mapping: blitter spec (`docs/rgc-blitter-surface-spec.md`)
= Bob/Paste Bob path; `SPRITE DRAW` = Sprite path; `TILE DRAW` (this doc)
= Paste Icon.

### Tilemap from array + text file

- `Dim MAP(cols, rows)` — 2D integer array of tile indices.
- `Open In 1,"map.txt"` + `Line Input #1,row$` + `Val(Mid$(row$,col,4))`
  — load map rows from ASCII text.

rgc-basic mapping: `TILEMAP DRAW slot, x0, y0, cols, rows, map()` takes
the same data shape (1-D row-major; AMOS uses 2-D but functionally
identical). Adopt the ASCII-text map file convention in docs — readable,
git-friendly, matches AMOS precedent.

### Scrolling — two distinct mechanisms

1. `Screen Offset screen, x_off, y_off` — shifts the **viewport** inside an
   oversized bitmap. No copy. "Moves our viewport, rather than the screen
   data". Paired with a bitmap bigger than the visible screen (e.g. 512+32
   tall) for wrap-around scrolling.
2. `Def Scroll zone, x1,y1 TO x2,y2, x_speed, y_speed` + `Scroll zone` —
   rectangular region + velocity. Activating it runs a blitter copy to
   shift the region's contents by the defined speed. "Under the hood, the
   Def Scroll approach is simply using the blitter". Good for parallax
   layers.

rgc-basic mapping:
- AMOS `Screen Offset` → `SCREEN OFFSET slot, x_off, y_off` on a blitter
  surface. Smooth scrolling without redrawing the tilemap each frame.
- AMOS `Def Scroll` / `Scroll` → `SCREEN ZONE zone, x1,y1,x2,y2,
  x_spd,y_spd` + `SCREEN SCROLL zone`. Region-based auto-scroll for
  parallax bands (e.g. sky=slow, ground=fast).

### Performance tips we should copy

- `Bob Update Off` — disables per-frame auto redraw; caller batches.
  `TILEMAP DRAW` batching rationale is the same idea at the tile level.
- Double-height virtual screen — allocate bitmap taller than visible,
  scroll via offset, wrap at the seam. Lets games scroll indefinitely
  without rebuilding the tilemap. This is a pattern for user code, not
  an API — but worth documenting as a recipe.

### Vocabulary we explicitly **don't** adopt

- "Bob" / "Icon" — too Amiga-specific. Keep `SPRITE` and `TILE`.
- `.abk` artwork bank (bundled sprites + tiles + palette in one file) —
  our per-PNG loading is simpler and web-friendly. Skip.
- Numbered Bob/Sprite slots with implicit global state — we already use
  explicit slot args; keep that.

### Derived action items for our specs

- Add `SCREEN OFFSET slot, x_off, y_off` to the blitter spec (viewport
  shift on a bitmap surface without copying).
- Add `SCREEN ZONE` / `SCREEN SCROLL` to either the blitter spec or a new
  `scrolling-viewport-plan.md`. Decide based on whether the scroll
  implementation is bitmap-blitter-backed (→ blitter spec) or
  GPU-retained (→ new doc).
- Document an ASCII map-file convention (rows of space-separated integers
  or 4-char fixed-width) in `TILEMAP DRAW` reference so user code has a
  standard to follow.

## Open questions

1. Should `TILEMAP DRAW` support a per-tile tint/alpha override, or is
   that sprite-only? Probably leave at "sheet's loaded colors" for v1.
2. Scroll offsets on `TILEMAP DRAW` — ship in v1 or defer in favour of
   `SCREEN OFFSET` on the surface? Suggest defer.
3. Should `z` default to the slot's current `SPRITE FRAME`-style z, or
   to 0? Probably 0 for tilemaps (backgrounds typically sit at a single
   depth).
4. Do we want a `TILEMAP` background-layer concept where a persistent
   map draws every frame automatically, or stay explicit per-frame?
   Explicit matches the rest of the API; implicit would need a new
   frame hook.
5. `SCREEN ZONE` / `SCREEN SCROLL` ownership — this spec, blitter spec, or
   new `scrolling-viewport-plan.md`? Answer depends on whether scroll
   regions operate on bitmap surfaces (blitter-backed) or on the
   tilemap/GPU path.
