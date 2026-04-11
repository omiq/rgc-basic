# RGC-BASIC: Blitter, Surfaces & In-Memory Images — Design Specification

**Status:** Draft for discussion and phased implementation  
**Audience:** Implementers (C/WASM/JS) and advanced BASIC authors (e.g. STOS/AMOS-style tools in BASIC)  
**Goal:** Add **rectangular copy** (blitter-style), **off-screen image buffers**, **region → sprite** capture, and **export** paths, with **feature parity** between **native** (`basic-gfx`) and **canvas WASM**, without breaking existing programs.

---

## 1. Vision

### 1.1 What we are building toward

- **AMOS/STOS-like workflow (subset):** Copy rectangles between buffers, scroll regions, build tile/sprite workflows from **BASIC** — enough to support **editors and utilities** written in RGC-BASIC (as the classic Amiga tools often were).
- **One language, two hosts:** Same statements and functions behave the same in **terminal + gfx** where applicable, and in **WASM canvas** (with documented limits).
- **Progressive disclosure:** Start with **bitmap-only** operations that map cleanly to existing `GfxVideoState` + software renderer; add **RGBA surfaces** and **export** when the foundation is solid.

### 1.2 What we are not building (v1)

- A full **Amiga blitter** (minterm, arbitrary masks, copper).
- **Dual independent playfields** with hardware-style priorities (we already approximate with layers + z-order sprites).
- **Binary compatibility** with AMOS/STOS file formats (`.abk`, etc.) — optional **later**; **PNG** remains the interchange format unless extended.

---

## 2. Design principles

1. **Explicit surfaces:** Every copy has a **named target** (default visible bitmap vs numbered off-screen image). No hidden global “blitter context” beyond current `SCREEN` mode.
2. **Predictable coordinates:** All rects use **pixel coordinates** in the **same space** as `PSET`/`LINE` in bitmap mode (0..319, 0..199 for default 320×200 unless extended).
3. **Clipping:** All operations **clip to destination bounds** (and optionally source); out-of-budget pixels are **no-ops**, not errors — unless `OPTION STRICT_CLIP` (optional future) is enabled.
4. **Deterministic limits:** Max surface count, max dimensions, max export size — **documented** and **queryable** from BASIC (`IMAGESIZE?` / `SYSINFO` pattern — exact names TBD).
5. **WASM parity:** Any feature that touches **memory** must have a **clear JS story** for **readback** (export) without re-entrancy bugs (follow `wasm_gfx_key_state_ptr` patterns: **export pointer + length**, or **copy-out** via async JS).

---

## 3. Current foundation (inventory)

### 3.1 Already in RGC-BASIC

| Area | Mechanism |
|------|-----------|
| Text + colour | `GfxVideoState.screen[]`, `color[]`, `SCROLL` offsets |
| Hi-res bitmap | 320×200 1 bpp packed buffer (`gfx_bitmap_*`, `PSET`/`LINE`) |
| PNG sprites | Slots, `LOADSPRITE`, `DRAWSPRITE`, tile sheets, `SPRITEMODULATE` |
| Memory model | Virtual `POKE`/`PEEK` bases; 64K-style addressing |

### 3.2 Gaps this spec fills

- **No** general **rectangular copy** between two raster buffers.
- **No** first-class **off-screen bitmap/RGBA** that BASIC names and addresses.
- **No** **grab screen region → sprite slot** without an intermediate PNG file.
- **No** **export** of a buffer to **PNG** or **raw bytes** for web download.

---

## 4. Conceptual model

### 4.1 Surface kinds (typed)

| Kind | Bits | Typical use |
|------|------|-------------|
| `BITMAP1` | 1 bpp, packed | Current `SCREEN 1` layer; fast; good for classic-style tools |
| `RGBA8` | 32 bpp premultiplied or straight-alpha | Scratch pads, “canvas” for tools, future true-color ops |

**Rule:** Phase 1 implements **`BITMAP1` only** for **COPY** between **same or two buffers** of the same kind. **RGBA** surfaces are **Phase 2+** (see §7).

### 4.2 Surface identifiers

- **Index `0`:** Reserved for the **visible** hi-res bitmap attached to the current gfx session (when `SCREEN 1` is active). Operations when `SCREEN 0` may **error** or **no-op** with hint — **TBD** (prefer **runtime error** with hint: “BITMAP COPY requires SCREEN 1”).
- **Index `1..N`:** **Off-screen** surfaces created with **`IMAGE CREATE`** (name TBD).

**Alternative syntax (discussion):** Named images: `IMAGE "work"` vs numeric `IMAGE 1`. Numeric scales better for arrays in BASIC; names aid readability. Spec recommends **numeric handles** + optional **alias** via `IMAGE NAME` later.

### 4.3 Coordinate system

- Origin **top-left** `(0,0)`, `x` right, `y` down.
- All rectangles: `x, y, width, height` **or** `x1,y1 TO x2,y2` — **one style** should win for consistency with `LINE` (which uses `x,y TO x,y`). **Recommendation:** mirror **`LINE`** / **`BAR`** style:  
  `COPY sx,sy TO dx,dy, w, h` **or**  
  `COPY sx1,sy1,sx2,sy2 TO dx,dy` (two corners) — pick one and document.

---

## 5. Feature set by phase

### Phase 1 — Bitmap rectangular copy (blitter-style, minimal)

**Scope:** 1 bpp buffers only; **copy** from **source rect** to **dest** in **same** image or **another** bitmap surface.

**Proposed statements (names illustrative):**

```
REM Create off-screen bitmap WxH (1 bpp), returns handle in variable or uses next slot
IMAGE CREATE img, 320, 200

REM Copy rectangle from surface src (0=screen bitmap) to surface dst at (dx,dy)
REM Clipped; overlapping copy may need temp row buffer (implementation detail)
IMAGE COPY src, sx, sy, sw, sh TO dst, dx, dy

REM Fill rect with 0 or 1 (bitmap pen)
IMAGE FILL dst, x, y, w, h [, mode]

REM Optional: scroll region by (dx,dy) with fill edge (classic scroll)
IMAGE SCROLL dst, x, y, w, h, dx, dy [, fill]
```

**Semantics:**

- **`IMAGE COPY`:** Bit-level copy; **source and dest format must match** (Phase 1: both `BITMAP1`).
- **Overlapping copy** on **same** buffer: must behave like **memmove**-safe (copy row-by-row in the correct direction) — specify in impl notes.
- **Performance:** Native C memcpy of packed rows; WASM same, **no** per-pixel JS.

**Errors:**

- Invalid handle, negative size, `SCREEN 0` when `src` or `dst` is `0` — clear **`Hint:`** lines.

---

### Phase 2 — RGBA surfaces & blending (optional, larger)

**Scope:** Allocate **`RGBA8`** surfaces (same dimensions limits as WASM heap allows).

- `IMAGE CREATE RGBA img, w, h` → transparent black or undefined cleared.
- Later: `IMAGE BLEND`, `IMAGE ALPHA` — **defer** until Phase 1 is stable.

**Use case:** Paint programs, icon editors — **not required** for “AMOS Screen Copy demo” parity.

---

### Phase 3 — Region → sprite slot (“grab”)

**Goal:** Avoid round-tripping through disk for tools.

**Proposed:**

```
REM Capture rectangle from bitmap surface src into sprite slot s as new texture
REM Equivalent to: crop WxH from (sx,sy), upload as PNG-like RGBA internally
IMAGE TOSPRITE src, sx, sy, sw, sh, slot [, tile_w, tile_h]
```

**Semantics:**

- **Source:** For Phase 1, **`BITMAP1` only** — conversion **1 bpp → RGBA** uses **foreground/background indices** from current `COLOR` / `BACKGROUND` or explicit **palette** parameters — **must be specified** (e.g. pen 1 = white, 0 = black for capture, or sample from PETSCII layer — **avoid** unless defined).

**Simpler v1:** **`IMAGE TOSPRITE` only from `RGBA8` surface** (Phase 2), OR **`TOSPRITE` from bitmap** uses **fixed two-colour** conversion. Document chosen rule.

**Interaction with `LOADSPRITE`:** Same slot rules — **replaces** texture for that slot; **`SPRITEMODULATE`** reset policy matches **`LOADSPRITE`**.

---

### Phase 4 — Export (CLI + WASM)

**Goal:** **Extract** image bytes for **download** or **processing**.

**Options (pick 1–2 for v1):**

| Method | CLI | WASM |
|--------|-----|------|
| **Raw 1bpp** | Write to `OPEN OUT` file | `HEAPU8` slice + JS download blob |
| **PPM/PGM** | Easy text PGM export | Same, or base64 string |
| **PNG** | **stb_image_write** (add dependency) or **miniz** | Same compiled to WASM |

**Proposed API:**

```
REM Write surface img raw 1bpp to file (path)
IMAGE SAVE img, "out.raw" [, format]

REM WASM: also expose via intrinsic
REM S$ = IMAGEEXPORT$(img, "png")   ' returns empty if too large / fail
```

**WASM contract:**

- **`_wasm_image_export_ptr(slot, format)`** → ptr + len, or
- **Chunked** export to **FS** (`/tmp/out.png`) + JS reads **FS** and triggers download (pattern already used in Emscripten tutorials).

**CORS / UX:** Document that **download** is **IDE responsibility** (button calling JS), not automatic.

---

## 6. STOS/AMOS-style editors in BASIC (target scenarios)

These scenarios **drive** API completeness:

| Tool | Needs |
|------|--------|
| **Tile painter** | Bitmap surface, `PSET`/`LINE`, `IMAGE COPY` to stamp tiles, optional **`TOSPRITE`** for preview |
| **Charset viewer** | Already partly `petscii-data.bas`; **`COPY`** helps **tile extract** |
| **Map editor** | 2D array + **`IMAGE COPY`** tiles from sheet surface to map surface |
| **Sprite grabber** | **`TOSPRITE`** from back-buffer |

**Editor loop:** `DO` … `GET` / `INKEY$` / `PEEK` … `IMAGE COPY` … `WAIT` / `SLEEP 1` — same as today.

---

## 7. API sketch (consolidated)

**Naming:** Replace **`IMAGE`** with **`BITMAP`** if we want to avoid confusion with “character image” — **open decision**.

| Statement / function | Phase |
|---------------------|-------|
| `IMAGE CREATE h, w, h` | 1 |
| `IMAGE COPY …` | 1 |
| `IMAGE FILL …` | 1 |
| `IMAGE FREE h` | 1 |
| `IMAGE TOSPRITE …` | 3 |
| `IMAGE SAVE` / `IMAGEEXPORT$` | 4 |
| `IMAGE CREATE RGBA …` | 2 |

**Introspection:**

- `IMAGEWIDTH(h)`, `IMAGEHEIGHT(h)`, `IMAGECOUNT()` or **`MAXIMAGES`**.

---

## 8. Implementation architecture (C)

### 8.1 Data structures

- Extend **`GfxVideoState`** or add **`GfxImageBank`**:
  - Array of **`GfxRasterSurface`** { `kind`, `w`, `h`, `stride`, `owned_ptr`, `bytes` }.
- Surface `0` = **alias** to existing **`bitmap[]`** when `SCREEN 1`.

### 8.2 Native (Raylib)

- **COPY** is **CPU**; optional **future:** upload **RGBA** surface to **Texture2D** for fast preview (not required for Phase 1).

### 8.3 WASM

- Surfaces live in **Wasm linear memory**; **`gfx_canvas`** compositor reads **visible** bitmap as today.
- **Export:** encode PNG in WASM **or** export **raw** and PNG-encode in **JS** (smaller WASM binary) — **tradeoff decision**.

### 8.4 Threading

- Same rules as sprites: **no OpenGL** from worker if **basic-gfx** worker thread; **COPY** is **CPU-only** → safe on worker **if** single-writer discipline holds.

---

## 9. Testing

- **Golden tests:** Small fixed patterns **COPY** and compare byte arrays (`tests/image_copy_test.c`).
- **BASIC regressions:** `tests/image_copy.bas` — deterministic output hash or **PEEK** sample points.
- **WASM:** Playwright: run program, **export**, compare **PNG** checksum or dimensions.

---

## 10. Open decisions (need your input)

1. **Keyword prefix:** `IMAGE` vs `BITMAP` vs `SURFACE`.
2. **Rect syntax:** `w,h` vs `x1,y1,x2,y2` only.
3. **`TOSPRITE` from 1 bpp:** **two-colour** fixed vs **palette** from PETSCII.
4. **PNG in WASM:** encode in C vs JS.
5. **Max surfaces / max WxH** on WASM (heap).

---

## 11. Summary

This spec aims for **honest parity** with **“screen copy + grab region + work buffer”** patterns from **AMOS/STOS**, not hardware emulation. **Phase 1** (**off-screen 1 bpp + `IMAGE COPY`**) unlocks most **editor-in-BASIC** value with **manageable** scope on **CLI and WASM**. **Export** and **RGBA** follow once the **surface allocator** and **COPY** semantics are proven.

---

*Document version: 0.1 — draft*
