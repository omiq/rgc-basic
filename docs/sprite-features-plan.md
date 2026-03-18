# Sprite Features – Planning & Specification

**Status**: Planning only. Do not implement yet.

This document outlines a sprite subsystem for `basic-gfx`, designed for modern hardware with no C64-style limits. The goal is to let BASIC programs load PNG images as sprites, draw them at arbitrary positions with depth ordering, and perform collision detection.

---

## 1. Design principles

- **No artificial limits**: Use as many sprites as needed; modern hardware handles hundreds easily. No palette or dimension restrictions inherited from the C64.
- **New commands**: Introduce dedicated `LOADSPRITE` and `DRAWSPRITE` (and related) rather than overloading `POKE`/`PEEK` for sprite data.
- **PNG as primary format**: PNG supports transparency/alpha and is widely supported by tools (Aseprite, GIMP, export from Unity/Godot, etc.).
- **1:1 loading**: Load images at native resolution—no automatic scaling unless explicitly requested.
- **Layered rendering**: Sprites have a Z/priority so they can be drawn in front of or behind other sprites and game objects (e.g. text layer, bitmap layer).

---

## 2. BASIC command set (proposed)

### 2.1 Loading sprites

**`LOADSPRITE slot, "path"`**

- Load a PNG file from the filesystem into a sprite slot.
- `slot`: numeric index (e.g. 0, 1, 2, …). Slots are managed internally; no fixed limit.
- `path`: string path to the `.png` file (relative to cwd or absolute).
- On success, the sprite is stored and can be referenced by `slot` in subsequent commands.
- On failure (file not found, invalid PNG): set `ST` or raise error; slot is unchanged.
- **1:1 semantics**: Image dimensions are preserved. A 32×32 PNG becomes a 32×32 sprite.

**`LOADSPRITE slot, "path", mode`**

- Optional `mode` for advanced loading:
  - `1` or `"sprite"`: single sprite, 1:1 (default).
  - `2` or `"tilemap"`: interpret image as a tile/sprite sheet; each tile is a fixed-size cell (e.g. 16×16 or 32×32). Creates multiple logical sprites or a tile grid from one file.
- Tilemap mode is deferred to a later phase; phase 1 is single-sprite 1:1 only.

### 2.2 Drawing sprites

**`DRAWSPRITE slot, x, y`**

- Draw the sprite in `slot` at screen coordinates `(x, y)`.
- `x`, `y`: pixel coordinates. Origin is top-left of the window (0,0).
- Coordinates can be fractional for sub-pixel positioning (optional; may start integer-only).
- Draw order is determined by a separate Z/priority system (see below).

**`DRAWSPRITE slot, x, y, z`**

- Same as above, with explicit Z/priority.
- Higher `z` = drawn in front (on top of lower-z objects).
- Default `z` = 0 if omitted.
- Suggested range: e.g. -1000 to 1000, or unbounded integers. Text layer and bitmap layer can use fixed Z bands (e.g. text at 100, sprites 0–99, background -100).

**`DRAWSPRITE slot, x, y, z, scale`**

- Optional scale factor: 1.0 = 1:1, 2.0 = double size, 0.5 = half.
- Deferred to later phase.

### 2.3 Sprite visibility and state

**`SPRITEVISIBLE slot, on`**

- `on`: 1 = visible (drawn), 0 = hidden (not drawn but still in memory).
- Allows toggling sprites without unloading.

**`SPRITEPOS slot, x, y`**

- Set position of a sprite for the next frame. Alternative to passing x,y every `DRAWSPRITE` call if sprites are persistent.
- Design choice: **immediate** (each `DRAWSPRITE` is a one-frame draw) vs **persistent** (sprites have position state that persists until changed). Recommend supporting both: `DRAWSPRITE` for immediate draw, and optional `SPRITEPOS` + a "draw all" pass for persistent sprites. This can be simplified in v1.

### 2.4 Collision detection

**`SPRITECOLLIDE(slot1, slot2)`**

- Function: returns -1 (true) if the bounding boxes of the two sprites overlap, 0 (false) otherwise.
- Or: return 1/0 for BASIC `IF SPRITECOLLIDE(0,1) THEN ...`.
- **Bounding box**: Axis-Aligned Bounding Box (AABB) based on current draw position and sprite dimensions. Simple and fast.
- **Pixel-perfect collision**: Optional later; AABB is sufficient for most games.

**`SPRITECOLLIDEX(slot1, slot2)`**

- Optional: return collision point or overlap depth. Deferred.

---

## 3. Architecture

### 3.1 Where sprites live

- **Sprite store**: A dynamic list or array of sprite descriptors.
  - Each entry: slot id, image data (RGBA texture or raylib `Texture2D` handle), width, height, visible flag, last-drawn position (if persistent).
- **No PEEK/POKE**: Sprite data stays in the gfx layer. BASIC only references slots by number.

### 3.2 Rendering pipeline

- Current `basic-gfx` render loop:
  1. Clear or draw background.
  2. Draw 40×25 text layer (PETSCII).
  3. (Future) Draw bitmap layer.
- **Insert sprite layer**:
  - After background, before or after text (configurable Z).
  - Each frame: collect all `DRAWSPRITE` calls (or iterate over "active" sprites with persistent state).
  - Sort by Z.
  - Draw from lowest Z to highest Z.

### 3.3 Coordinate system

- Window size: 960×600 (320×200 × 3) or configurable.
- Sprite `(x,y)` = pixel position of top-left corner of sprite in window pixels.
- Off-screen drawing: Clipped by raylib or allowed (sprites can be partially or fully off-screen).

### 3.4 File format: PNG

- Use raylib’s `LoadImage` / `LoadTexture` for PNG. Raylib supports PNG with alpha.
- On load: decode PNG, upload to GPU as texture (or keep in RAM if needed for collision). Store width/height.
- Path: relative to current working directory (same as `OPEN` for files).

---

## 4. Implementation strategy

### Phase 1 – Minimal viable sprites

1. **Sprite store**: Add a simple sprite array to `GfxVideoState` or a separate `GfxSpriteState`. Max 64 or 128 sprites initially (configurable constant).
2. **LOADSPRITE slot, "path"**:
   - Parse and validate.
   - Load PNG via raylib.
   - Store texture + dimensions in slot.
   - Handle errors (file not found, bad format).
3. **DRAWSPRITE slot, x, y [ , z ]**:
   - Add a draw command to a frame-local queue, or draw immediately in the render thread.
  - Recommendation: **queue draws per frame** – during BASIC execution, collect `(slot, x, y, z)`; at end of frame, sort by Z and draw. This avoids threading issues.
4. **Rendering**: In the raylib render loop, after text (or between layers), render queued sprites sorted by Z.
5. **SPRITEVISIBLE slot, on**: Simple flag in sprite descriptor.

### Phase 2 – Collision and polish

6. **SPRITECOLLIDE(slot1, slot2)**: Implement AABB overlap. Require that both sprites were drawn this frame (or have stored position). Compare rectangles.
7. **Persistent position** (optional): `SPRITEPOS slot, x, y` and a "draw all visible sprites" mode.
8. **Scale** (optional): `DRAWSPRITE slot, x, y, z, scale`.

### Phase 3 – Tilemaps and advanced loading

9. **LOADSPRITE slot, "path", "tilemap"**: Parse image as grid of tiles. Define tile width/height (e.g. 16×16). Create multiple sub-sprites or a tilemap layer.
10. **Other formats**: Consider supporting JPEG, BMP, or raw data later.

---

## 5. Open questions

- **Immediate vs persistent draws**: Should `DRAWSPRITE` be “draw this sprite this frame at (x,y)” or “set sprite position to (x,y) and it will be drawn every frame until changed”? Recommendation: start with immediate (explicit draw each frame), add persistent mode later.
- **Z bands for built-in layers**: Define fixed Z for text (e.g. 100), sprites (user 0–99), bitmap (-100). Or allow sprites to go behind text?
- **Slot recycling**: When loading into a used slot, free old texture? Yes.
- **Error handling**: `LOADSPRITE` into missing file: set `ST`? Or `ON ERROR`? Match existing file I/O semantics.
- **Multiple images per slot**: e.g. animation frames. Deferred; could be `LOADSPRITE slot, "path", frame` or separate command.

---

## 6. Example usage (target)

```basic
REM Load sprites
LOADSPRITE 0, "player.png"
LOADSPRITE 1, "enemy.png"

REM Game loop (conceptual)
10 PX = 160 : PY = 100
20 DRAWSPRITE 0, PX, PY, 10    REM player at z=10 (in front)
30 DRAWSPRITE 1, 200, 100, 5   REM enemy at z=5 (behind player)
40 IF SPRITECOLLIDE(0, 1) THEN PRINT "HIT!"
50 GOTO 10
```

---

## 7. Dependencies

- **Raylib**: Already in use; `LoadImage`, `LoadTexture`, `DrawTexture` (or `DrawTexturePro` for scaling) support PNG and alpha.
- **basic.c**: New statement handlers for `LOADSPRITE`, `DRAWSPRITE`, `SPRITEVISIBLE`; new function `SPRITECOLLIDE`.
- **gfx_raylib.c**: Extend render loop to draw sprite queue.
- **gfx_video.h/c**: Optional `GfxSpriteState` or extend `GfxVideoState` with sprite arrays. Keep raylib-specific texture handles out of `gfx_video` if we want headless testability; or accept that sprites require raylib.

---

## 8. Non-goals (for now)

- Palette restrictions or C64 colour limits.
- Fixed sprite dimensions (e.g. 24×21).
- Sprite multiplexing or hardware limits.
- Pixel-perfect (non-AABB) collision.
- Animation (multiple frames per slot).
- Rotation.
- Tilemap loading from a single image (Phase 3).
- Other image formats (JPEG, etc.) – can add when needed.
