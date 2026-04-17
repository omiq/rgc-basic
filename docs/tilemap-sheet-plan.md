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

## API (proposed)

### Loading

- `LOADSPRITE slot, path [,cell_w, cell_h]` (unchanged)
  - With cell dims → treated as a sheet.
  - Without cell dims → single image (1×1 sheet).
- `SHEETCELLS(slot)` — new; returns total cells in the sheet.
  - `SPRITETILES(slot)` kept as a deprecated alias → prints a one-time
    warning on use, removed in +2 releases.

### Animation (single-sprite use)

- `SPRITEFRAME slot, n` — set current animation frame (unchanged).
- `DRAWSPRITE slot, x, y [,z]` — draws the current frame (unchanged).

Rationale: nothing changes for animators. They never reach for "tile".

### Tileset use (explicit single draw)

- `DRAWTILE slot, x, y, tile_idx [,z]` — new canonical name.
  - `DRAWSPRITETILE` kept as a deprecated alias.
- Semantic: stateless; does not mutate `SPRITEFRAME`.

### Batched tilemap

- `DRAWTILEMAP slot, x0, y0, cols, rows, map()`
  - `map()` is a 1-D BASIC integer array of length `cols*rows`, row-major,
    tile indices. `0` = transparent (skip draw).
  - Draws all cells in one interpreter dispatch. The runtime iterates
    internally in C and issues one batched GPU draw where possible (raylib:
    one `DrawTexturePro` per cell but inside C; WASM: one native loop, no
    asyncify overhead per tile).
  - `z` is whatever is current for that slot (or an optional trailing arg
    `[,z]`).

Optional extension for scrolling:

- `DRAWTILEMAP slot, x0, y0, cols, rows, map(), src_x, src_y`
  - `src_x, src_y` shift the sample origin inside the map so the top-left
    cell reads from an offset. Lets BASIC implement smooth scrolling
    without rebuilding the map each frame.

## Implementation notes

### basic.c

1. Tokenise `DRAWTILE`, `DRAWTILEMAP`, `SHEETCELLS`.
2. `SPRITETILES` and `DRAWSPRITETILE` paths stay; emit one-time deprecation
   notice via `runtime_warn_once`.
3. `DRAWTILEMAP`: fetch array address + length, validate, call
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

- Native: the gain over per-call `DRAWSPRITETILE` is marginal (interpreter
  dispatch is already cheap on desktop). Still worth it for readability.
- WASM: big win. Each interpreter statement hits the asyncify yield-point
  path (~1 µs). Drawing 1000 tiles as 1000 statements ≈ 1 ms just in
  overhead. One `DRAWTILEMAP` = one yield-point crossing.

### BASIC-level migration

Ship release N:
- Add new names.
- Keep old names as aliases.
- Print deprecation notice at first use.

Release N+1:
- Flip docs to the new names.
- Keep aliases, no notice change.

Release N+2:
- Remove deprecated aliases.

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

## Open questions

1. Should `DRAWTILEMAP` support a per-tile tint/alpha override, or is that
   sprite-only? Probably leave at "sheet's loaded colors" for v1.
2. Scroll offsets — ship in v1 or defer? Suggest defer.
3. Should `z` default to the slot's current `SPRITEFRAME`-style z, or to 0?
   Probably 0 for tilemaps (backgrounds typically sit at a single depth).
4. Do we want a `TILEMAP` background-layer concept where a persistent map
   draws every frame automatically, or stay explicit per-frame? Explicit
   matches the rest of the API; implicit would need a new frame hook.
