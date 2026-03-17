## Bitmap / Graphics Feature – Technical Plan

Target: feature branch (suggested) `feature/raylib-gfx` adding a **graphics-enabled variant** of the interpreter using [raylib](https://www.raylib.com/). The goal is a C64‑flavoured environment with:

- Full **40×25 PETSCII text screen** rendered via a bitmap/font, not the host terminal.
- **Memory‑mapped screen and colour RAM**, readable/writable via `PEEK`/`POKE`.
- **User‑defined characters** (UDGs) with a CHAR-ROM‑like bitmap.
- A 320×200 **hi‑res pixel mode** (and possibly multicolour) under BASIC control.

This document is the planning baseline for version **gfx-0.1** on top of CBM-BASIC 1.0.0.

---

## 1. Architecture / Process model

- **Separate binary**: keep `basic` (terminal/ANSI) as-is and add a new target, e.g.:
  - `basic-gfx` or `basic-raylib`
  - Built from the same core (`basic.c`, PETSCII tables), plus:
    - `gfx_runtime.c` / `gfx_runtime.h` – graphics subsystem.
    - `gfx_raylib.c` – raylib-specific window + render loop.
- **Execution model**:
  - BASIC still runs in a **single thread**; the raylib render loop polls a shared “video state” struct every frame.
  - Input:
    - Keyboard events go into a small queue exposed to BASIC via extended `GET`/`INKEY$` later.
  - Video:
    - BASIC modifies in‑memory screen/bitmap; the renderer just mirrors memory → pixels each frame.

Advantages: keeps core interpreter almost unchanged and lets us build/ship graphics support independently from the terminal version.

---

## 2. Video memory model

### 2.1 Text mode (40×25)

- **Screen RAM**: 1000 bytes, linear:
  - `TEXT_BASE = 0x0400` (C64-style), indices 0–999.
  - Mapping: row `r` (0–24), col `c` (0–39) → `addr = TEXT_BASE + r*40 + c`.
- **Colour RAM**: 1000 bytes:
  - `COLOR_BASE = 0xD800` equivalent (virtual), 0–15 palette indices per cell.
- **Character generator**:
  - 256 chars × 8 bytes per char for **8×8 glyphs**.
  - Default content: C64 upper/graphics ROM (approximated), stored in:
    - `CHAR_BASE = 0x3000` virtual region (256×8 = 2048 bytes).
  - **User‑defined characters**:
    - BASIC can `POKE` into this region to redefine glyphs.

### 2.2 Bitmap mode (320×200)

- **Hi‑res bitmap**:
  - `BITMAP_BASE` = 0x2000 (e.g.) – 320×200 monochrome or 2‑bit pixels.
  - Simplest first cut: 1 bit per pixel (monochrome) = 320×200 / 8 ≈ 8000 bytes.
  - Later extension: 2‑bit per pixel or per‑cell colour like C64 hires/multicolour.

### 2.3 PETSCII and screen codes

- Reuse existing **PETSCII → glyph index** mapping.
- For text output (PRINT, CHR$) in gfx mode:
  - Instead of writing to terminal, write **screen codes** into screen RAM and colour into colour RAM.
  - Cursor position is tracked in terms of row/col; screen writes update the mapped bytes.

---

## 3. BASIC integration (POKE/PEEK and modes)

### 3.1 PEEK/POKE semantics

- Today, `POKE` is a no‑op; in gfx branch we will give it meaning for **video ranges**:
  - If address ∈ `[TEXT_BASE, TEXT_BASE+1000)` → update screen RAM.
  - If address ∈ `[COLOR_BASE, COLOR_BASE+1000)` → update colour RAM.
  - If address ∈ `[CHAR_BASE, CHAR_BASE+2048)` → update character glyphs.
  - If address ∈ `[BITMAP_BASE, BITMAP_BASE+bitmap_size)` → update bitmap VRAM.
- `PEEK(addr)` returns from the same in‑memory arrays for those ranges.
- Addresses outside these ranges remain “virtual”:
  - For now return 0 for `PEEK` and ignore `POKE` (or later provide an extensible hook).

### 3.2 Graphics mode control

Add non-standard statements (gfx branch only):

- `SCREEN 0` – text mode (40×25).
- `SCREEN 1` – hires bitmap mode (320×200, monochrome).
- Optional later: `SCREEN 2` – multicolour.

Internally:

- `screen_mode` enum (`TEXT`, `BITMAP`).
- Render loop chooses text or bitmap path based on this flag.

---

## 4. Raylib layer

### 4.1 Window and main loop

- Window size: 640×400 or 960×600 (integer scale of 320×200).
- Use a single `RenderTexture2D` at 320×200, scaled up with `DrawTexturePro`.
- Main loop:
  - Poll events (for ESC/close, keyboard).
  - Draw frame from current video memory.
  - Maintain a fixed or vsync‑locked framerate.

### 4.2 Text renderer

- Each frame, for TEXT mode:
  - For each cell (r,c):
    - Read screen code and colour.
    - Lookup 8×8 bitmap for that char from CHAR memory.
    - Blit 8×8 block into the texture with foreground/background colours from colour RAM and a global background.
  - Optimise later by dirty rectangles or per‑cell change tracking.

### 4.3 Bitmap renderer

- For BITMAP mode:
  - Walk BITMAP memory, unpack bits to pixels.
  - Initially monochrome (single foreground/background colour).
  - Later: support per‑cell colour or full palette.

---

## 5. Branch / code organisation

Suggested branch: **`feature/raylib-gfx`**.

Directory structure:

- `gfx/`:
  - `gfx_video.h` – struct definitions, constants (TEXT_BASE, COLOR_BASE, etc.), API.
  - `gfx_video.c` – implementation of video memory, helpers for PEEK/POKE ranges.
  - `gfx_raylib.c` – raylib entry point + render loop.
- `basic.c`:
  - Remains the **single source of truth** for language semantics.
  - Gated changes:
    - New PEEK/POKE behaviour in video ranges behind `#ifdef GFX_VIDEO`.
    - A compile‑time option or separate `main()` in `gfx_raylib.c` that calls `run_program()` and pumps raylib.

---

## 6. Incremental to‑do list

**Phase 1 – Skeleton & build**

1. Add `gfx_video.h/.c` with:
   - Video state struct (screen RAM, colour RAM, char RAM, bitmap RAM).
   - Initialiser and clear functions.
2. Add `gfx_raylib.c` with a minimal window + render loop that fills the screen with a solid colour.
3. Add a new Makefile target `basic-gfx` that links `basic.c`, `petscii.c`, `gfx_video.c`, `gfx_raylib.c` with raylib.

**Phase 2 – Text screen via PEEK/POKE**

4. Implement screen RAM + PETSCII mapping in `gfx_video.c`.
5. Teach `PRINT` / `CHR$` (in gfx build) to write to screen RAM instead of stdout.
6. Implement raylib text renderer using the char ROM bitmap and colour RAM.
7. Wire `POKE`/`PEEK` to TEXT_BASE and COLOR_BASE ranges.
8. Add small demo(s): text scroller, PETSCII art, user‑defined characters.

**Phase 3 – Bitmap mode**

9. Define BITMAP_BASE and implement bitmap RAM.
10. Implement `SCREEN 1` statement and mode switch.
11. Implement hires bitmap renderer (monochrome).
12. Add helpers (possibly non-standard) like `PSET x,y` later, built on top of PEEK/POKE.

**Phase 4 – Polish & compatibility**

13. Cursor, scrolling, and wrap behaviour matching current text mode semantics.
14. Optional multicolour and more accurate C64 palette.
15. Keyboard mapping improvements and eventual joystick/gamepad input.

---

## 7. Risks and considerations

- **Performance**: naïve full redraw of 40×25×8×8 per frame is fine for modern hardware, but we may need dirty‑cell optimisations for very large BASIC programs.
- **Portability**: raylib is cross-platform, but the graphics build will depend on its presence. Keep the terminal `basic` build fully functional without raylib.
- **Semantics**: PEEK/POKE should feel C64‑like but we are not building a full emulator; document exactly which address ranges are meaningful.

This plan is intentionally modular: we can merge the branch at the end of any phase while keeping `basic` stable.

