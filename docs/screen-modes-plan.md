# Extended SCREEN Modes / Resolutions Plan

**Status:** Proposal.
**Owner:** Chris Garrett.
**Date:** 2026-04-17.
**Depends on:** renderer migration (`docs/wasm-webgl-migration-plan.md`) is NOT a hard prerequisite — phase 1 and 2 work on the current renderer. Phase 3 (higher resolutions on web) is where raylib-emscripten pays off.

---

## 1. Goals

- Support additional screen modes / resolutions beyond the current `SCREEN 0` (40×25 text) and `SCREEN 1` (320×200 1bpp bitmap).
- Keep the existing low-res modes backwards-compatible: POKE/PEEK screen RAM + colour RAM + keyboard matrix at documented addresses still works.
- New hi-res modes do NOT expose POKE addressing. Sprite and primitive APIs (`PSET`, `LINE`, `DRAWTEXT`, `LOADSPRITE`, `DRAWSPRITE`, future) are the drawing surface.
- Allow `SCREEN n` to switch modes mid-program — mode change reallocates buffers, clears screen, returns control.
- Extend palette to 256-color indexed as the near-term ceiling. Higher (RGBA / 24-bit) deferred to a later phase.

## 2. Non-goals

- Dropping support for `SCREEN 0` / `SCREEN 1`. They remain the primary PETSCII / retro experience.
- Hardware-accelerated shader effects (CRT scanlines, glow, etc.) — separate plan.
- Tile / sprite atlases beyond what `LOADSPRITE` already does.
- 3D. Not happening.

## 3. Mode numbering

| Mode | Resolution | Palette | POKE? | Introduced | Notes |
|------|------------|---------|-------|------------|-------|
| `SCREEN 0` | 40×25 text (optional 80×25) | 16-colour C64 | yes | existing | Text RAM 1024, colour RAM 55296. |
| `SCREEN 1` | 320×200 1bpp bitmap | 16-colour (fg/bg) | yes | existing | `BITMAPCLEAR`, `PSET`, `LINE`, text-in-bitmap. |
| `SCREEN 2` | 640×200 1bpp bitmap | 16-colour (fg/bg) | no | new, phase 2 | Widescreen retro; 2× horizontal of mode 1. |
| `SCREEN 3` | 640×480 1bpp bitmap | 16-colour (fg/bg) | no | new, phase 2 | VGA hi-res, mono. |
| `SCREEN 4` | 320×200 8bpp indexed | 256 | no | new, phase 3 | VGA mode 13h analogue. |
| `SCREEN 5` | 640×200 8bpp indexed | 256 | no | new, phase 3 | Widescreen 256-color. |
| `SCREEN 6` | 640×480 8bpp indexed | 256 | no | new, phase 3 | VGA mode 12h-ish. |
| `SCREEN 7+` | reserved | — | — | future | 24-bit RGB / RGBA / tilemap. |

Text mode parity in hi-res: if `PRINT` / `TEXTAT` / `DRAWTEXT` are used in `SCREEN 2+`, glyphs are stamped into the framebuffer using the same 8×8 char ROM and letterboxed/clipped to resolution. `LOCATE` snaps to 8-pixel cells.

## 4. BASIC-level API

### 4.1 Mode selection

```
SCREEN mode
```

- Integer in 0..6 (growing). Errors on unknown mode.
- Mode switch clears the framebuffer, resets fg/bg to sensible defaults for that mode, and invalidates any sprite z-order cached state (sprites themselves persist).
- Existing `SCREEN 0` / `SCREEN 1` semantics are unchanged.

### 4.2 Mode introspection

```
n = SCREENMODE      ' current mode number
w = SCREENWIDTH     ' pixel width of current mode
h = SCREENHEIGHT    ' pixel height of current mode
c = SCREENCOLORS    ' 16 or 256
```

Lets portable programs ask at runtime rather than hardcoding.

### 4.3 Drawing in `SCREEN 2+`

- `COLOR idx`, `BACKGROUND idx` — indexed palette entry. 0..15 for modes 2/3 (map to same 16-color palette). 0..255 for modes 4/5/6.
- `PSET x, y [, c]`, `PRESET x, y` — same semantics as mode 1, coord range is mode-specific.
- `LINE x1, y1 TO x2, y2 [, c]` — same.
- `BITMAPCLEAR` — clears to background.
- `RECT`, `FILL` (new, phase 2) — convenient primitives; implementable in mode 1 too as a backport, but lead in `SCREEN 2+`.
- `PRINT` / `TEXTAT` / `LOCATE` — glyph stamp at 8×8 cells.
- `DRAWTEXT x, y, "string" [, fg, bg]` — pixel-space text (scheduled in `docs/bitmap-text-plan.md`).
- `LOADSPRITE`, `DRAWSPRITE`, `SPRITECOPY`, `SPRITEMOVE`, etc. — unchanged API, new modes just have more room.

### 4.4 Disallowed in `SCREEN 2+`

- `POKE 1024+offset, ch` — no text RAM at fixed address. Error: "POKE screen RAM only in SCREEN 0/1".
- `POKE 55296+offset, col` — no colour RAM. Same error.
- `PEEK 1024` etc. — same.

Keyboard matrix `PEEK(56320+n)` stays available in all modes (it's input, not framebuffer).

### 4.5 Palette in 256-color modes

```
PALETTE idx, r, g, b
```

- `idx` 0..255, `r/g/b` 0..255.
- Entries 0..15 default to the C64 16-color palette for continuity; programs may override.
- Palette persists across mode switches within the same 256-color class; reset on switch to/from 16-color.

## 5. Implementation phases

### Phase 1 — runtime-sized buffers (blocks nothing, enables everything)

**Scope**: refactor `gfx/gfx_video.c/h` and both renderers so the bitmap plane, text RAM, colour RAM, and sprite-composite target are runtime-sized, not compile-time `#define`d. No new BASIC-level modes yet.

**Files**:
- `gfx/gfx_video.h`: replace `GFX_BITMAP_WIDTH`/`HEIGHT` `#define`s with fields on `GfxVideoState` (`bitmap_w`, `bitmap_h`, `bitmap_bpp`). Keep the `#define`s as default values for mode 1.
- `gfx/gfx_video.c`: replace static `uint8_t bitmap[GFX_BITMAP_BYTES]` with a `uint8_t *bitmap` + allocated length. Add `gfx_video_set_mode(GfxVideoState *, int mode)` that allocates/reallocates.
- `gfx/gfx_raylib.c`: `ensure_pixbuf` and `LoadRenderTexture(nat_w, nat_h)` already re-allocate on size change. Minor: `nat_w`/`nat_h` in `main` become mode-dependent, re-queried after each `SCREEN` call via a getter. Letterbox/fullscreen code unaffected.
- `gfx/gfx_canvas.c` (FROZEN per `docs/wasm-webgl-migration-plan.md` §4.1 — but this is a refactor not a feature, borderline): make the RGBA buffer runtime-sized. Since canvas is frozen, **prefer** to keep canvas at fixed 320×200 and implement the new modes raylib-side only. Programs using new modes on the canvas renderer get a runtime error "SCREEN mode N not available on canvas renderer; use ?renderer=raylib".
- `basic.c`: `SCREEN` statement handler validates mode number and calls `gfx_video_set_mode`.

**Tests**: existing `SCREEN 0` / `SCREEN 1` tests keep passing. Add regression test that switches `SCREEN 0 → 1 → 0` mid-program and verifies no memory corruption.

**Output**: no user-visible change. Foundation laid.

### Phase 2 — 16-color hi-res modes (`SCREEN 2`, `SCREEN 3`)

**Scope**: enable the two 1bpp widescreen / VGA hi-res modes using the same palette model as `SCREEN 1`. Sprites + primitives + glyph text all working.

**Files**:
- `gfx/gfx_video.c`: extend `gfx_video_set_mode` to handle modes 2 and 3. `gfx_bitmap_get_pixel` / `gfx_bitmap_set_pixel` already take `(x,y)` and mask into packed bits — only the stride (`GFX_BITMAP_WIDTH / 8u`) needs replacing with `s->bitmap_w / 8`.
- `gfx/gfx_raylib.c`: `render_bitmap_screen` uses `s->bitmap_w`/`s->bitmap_h` instead of macros. `nat_w`/`nat_h` in `main` track current mode. `LoadRenderTexture` resized on mode change (free old + load new).
- `basic.c`: `SCREEN` accepts 0..3. `SCREENMODE`/`SCREENWIDTH`/`SCREENHEIGHT`/`SCREENCOLORS` builtins added.
- Sprite path: `gfx_sprite_*` already samples screen dims from the video state; verify no hardcoded 320/200.

**Tests**:
- Draw a single-pixel outline at `(0,0)` / `(639,479)` in mode 3; verify both corners rendered.
- Fullscreen with mode 3 on a 16:9 monitor → pillarbox bars on sides (4:3 content).
- Mid-program switch `SCREEN 1 → 3 → 1` preserves sprite slots.

### Phase 3 — 256-color modes (`SCREEN 4/5/6`) + PALETTE

**Scope**: 8bpp indexed framebuffer, programmable palette, same resolutions as phase 2 plus `SCREEN 4` for low-res 256-color.

**Files**:
- `gfx/gfx_video.h/c`: add 8bpp code path. `GfxVideoState` gets `bitmap_bpp` field (1 or 8). Backing buffer becomes `uint8_t *bitmap` where size = `w * h` bytes for 8bpp, `(w * h) / 8` for 1bpp. `gfx_palette[256]` (`Color[256]`) added.
- `gfx/gfx_raylib.c`: `render_bitmap_screen` branches on `s->bitmap_bpp`: 1bpp existing path, 8bpp new path doing palette lookup per pixel into `g_pixbuf` (still 1 CPU pass, then 1 GPU upload).
- `basic.c`: `PALETTE idx, r, g, b` statement. `SCREEN` accepts 0..6. `COLOR` / `BACKGROUND` accept 0..255 in 256-color modes.

**Tests**:
- Set palette entry 200 to RGB(255, 128, 0); `PSET 10, 10, 200`; grab screenshot; assert that pixel is orange.
- `SCREEN 1 → 4 → 1`: entering 256-color resets palette 0..15 to C64 defaults on exit.

### Phase 4 — future (not this plan)

- 24-bit / RGBA direct-color mode (e.g. `SCREEN 7` 640×480 RGBA).
- Tilemap-native mode (`SCREEN 8`?) with a tile atlas and scroll registers.
- CRT / scanline / bloom shader post-process on the final `DrawTexturePro` pass. Raylib `BeginShaderMode` + GLSL fragment shader.

## 6. Memory / performance notes

Buffer sizes:

| Mode | Framebuffer bytes | WASM memory impact |
|------|-------------------|--------------------|
| 1 (320×200 1bpp) | 8,000 | baseline |
| 2 (640×200 1bpp) | 16,000 | +8 KB |
| 3 (640×480 1bpp) | 38,400 | +30 KB |
| 4 (320×200 8bpp) | 64,000 | +56 KB |
| 5 (640×200 8bpp) | 128,000 | +120 KB |
| 6 (640×480 8bpp) | 307,200 | +299 KB |

Plus the renderer's CPU-side `Color[w*h]` buffer (4 bytes per pixel): mode 6 = 1.2 MB. Mode 6 on current `gfx_canvas.c` software path would struggle on older CPUs (1.2 M pixels × 60 fps = 73 M pixel writes/s just for the clear-and-upload). Raylib path = GPU-upload once, GPU-composite sprites on top — trivial.

This is the concrete reason phase 3 (640×480 256-color) really wants the raylib-emscripten migration first on web. Desktop is already fine either way.

## 7. Open questions

- Should mode switch preserve content in the new framebuffer (e.g. when going 1 → 3, upscale the old contents)? Or always clear? Default: **always clear**, simpler and matches DOS-era behaviour. Reopen if users complain.
- Keep PETSCII char ROM for text in hi-res modes, or allow a custom font per mode? Phase 2 uses existing 8×8 ROM. Custom fonts tracked in `docs/bitmap-text-plan.md`.
- Runtime cost of per-mode render target recreate on frequent `SCREEN` switches? Probably fine (mode switches are rare) but cache last two targets if it becomes a hot path.
- WASM canvas path (frozen): definitely lock to SCREEN 0/1 only and error on SCREEN 2+? Or attempt a CPU-only 16-color hi-res to keep feature parity? **Proposal**: error, with a clear message pointing to `?renderer=raylib`. Keeps the freeze clean and the raylib path's value visible.
- Sprite coordinate space: sprites placed in mode-1 coordinates (320×200) stay visually small in `SCREEN 3` (640×480). Intended behaviour: sprites use framebuffer-pixel coords, so mode switch changes effective scale. Alternative: add `SPRITESCALE factor` / make sprites scale-aware. Decide during phase 2 implementation.

## 8. Success criteria

- Existing `examples/*.bas` programs using `SCREEN 0` / `SCREEN 1` run identically after phase 1 refactor (byte-for-byte framebuffer regression test OK).
- `examples/gfx_hires_demo.bas` (new, phase 2) runs on `basic-gfx` native and on the raylib-emscripten WASM path with identical output.
- Phase 3 adds `examples/gfx_256color_demo.bas` with a palette fade.
- No canvas renderer regressions during any phase (canvas stays on `SCREEN 0/1` only; clear error for other modes).
