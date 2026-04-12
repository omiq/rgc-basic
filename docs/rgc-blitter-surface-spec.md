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

## 6. Periodic timers (“IRQ-light”) — alternative to AMOS AMAL

### 6.1 Motivation

**AMOS AMAL** bundled a **mini animation language** tied to **channels** (bobs, sprites, screen offset) so movement could run **in parallel** with your main BASIC logic — a form of **cooperative multitasking** without threads.

RGC-BASIC is **unlikely** to adopt AMAL-style syntax. A more flexible, familiar pattern is **periodic invocation of ordinary BASIC** (subroutine or `FUNCTION`), similar to:

- **Visual Basic `Timer`**: `Interval` in ms, `Enabled`, tick fires → call handler.
- **“IRQ-light”**: not a hardware interrupt — a **scheduled callback** the runtime dispatches when **safe**.

That gives the **same practical benefit** as AMAL for cases like **starfields**, **background scrolling**, or **HUD clocks** while **`INPUT` / `INKEY$` / main loop** handle player control — without learning a second language.

### 6.2 Design constraints (must be explicit)

| Constraint | Rationale |
|------------|-----------|
| **Cooperative** | The interpreter is **single-threaded**; there is no preemptive IRQ into arbitrary BASIC mid-statement. |
| **Safe points** | Timer handlers run only at **defined boundaries**: e.g. **between statements**, **start of each gfx frame**, or when **`SLEEP` / `WAIT`** yields — **TBD** per implementation. |
| **Re-entrancy** | If the user is inside **`INPUT`**, **`GET`**, or **`SLEEP` (Asyncify)**, the runtime must either **queue** the tick or **defer** until **re-entrant-safe** (same class of problems as **`SPRITEMODULATE` + deferred `LOADSPRITE`** on WASM). |
| **basic-gfx** | **No** real second POSIX thread calling into the interpreter while Raylib runs; timer = **logical due counter** advanced by the **main loop** or **worker sync**, not `pthread_timer`. |
| **WASM** | **`setInterval`** in JS can bump a **counter** or **flag** in **`HEAP32`**; WASM **consumes** ticks when safe (mirror **`wasm_gfx_key_state_ptr`** / no **`ccall`** during Asyncify suspend). |

### 6.3 Proposed surface API (illustrative)

**Option A — GOSUB to a line label (CBM-flavoured):**

```
TIMER 1, 50, GOSUB 500     ' timer id 1, every 50 ms, branch to line 500
TIMER STOP 1
TIMER ON 1
```

**Option B — named procedure (if/when `CALL` / procedure labels align):**

```
TIMER 1, 50, CALL MoveStarfield
```

**Option C — polling only (simplest, zero re-entrancy):**

```
' Runtime sets TIMERDUE(1)=1 when interval elapsed; user clears in handler
IF TIMERDUE(1) THEN GOSUB 500 : TIMERACK 1
```

**Units:** **`ms`** (wall) matches **VB**; optional **`JIFFIES`** or **1/60 s** alias for parity with **`TI`** — **open decision**.

**Limits:** Max **N** concurrent timers (small integer ids **1..N**); minimum interval (e.g. **16 ms** clamp) to avoid tight loops.

### 6.4 Relationship to this spec

- **Blitter / `IMAGE COPY`**: A timer handler can **`IMAGE COPY`** a strip for **parallax**, **scroll** a region, or **nudge** star positions **without** stuffing all logic in the main `DO` loop.
- **Sprites**: Timer can update **`DRAWSPRITE`** positions or **`SPRITEFRAME`** — same as today’s main loop, just **scheduled**.
- **Not in Phase 1** for blitter work: timers are **orthogonal**; implement **after** or **in parallel** with **Phase 1 `IMAGE COPY`**, but **document together** so tool authors see the full **STOS/AMOS-like** toolkit.

### 6.5 Non-goals (v1)

- **Preemptive** real-time guarantees (use native extensions if ever needed).
- **AMAL** syntax compatibility or **channel** binding to animation strings.
- **Multiple OS threads** executing BASIC concurrently.

### 6.6 Open decisions

1. **Dispatch point:** per **frame** vs **between every statement** (latter is expensive in WASM).
2. **Handler form:** **`GOSUB` line** vs **`CALL` name** vs **polling `TIMERDUE`** only.
3. **GFX-only vs terminal:** Timers may be **no-op** or **error** in **`./basic`** without **`GFX_VIDEO`** — prefer **allowed** with wall-clock on POSIX for **console demos** — **TBD**.

---

## 7. STOS/AMOS-style editors in BASIC (target scenarios)

These scenarios **drive** API completeness:

| Tool | Needs |
|------|--------|
| **Tile painter** | Bitmap surface, `PSET`/`LINE`, `IMAGE COPY` to stamp tiles, optional **`TOSPRITE`** for preview |
| **Charset viewer** | Already partly `petscii-data.bas`; **`COPY`** helps **tile extract** |
| **Map editor** | 2D array + **`IMAGE COPY`** tiles from sheet surface to map surface |
| **Sprite grabber** | **`TOSPRITE`** from back-buffer |

**Editor loop:** `DO` … `GET` / `INKEY$` / `PEEK` … `IMAGE COPY` … `WAIT` / `SLEEP 1` — same as today.

---

## 8. API sketch (consolidated)

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

## 9. Implementation architecture (C)

### 9.1 Data structures

- Extend **`GfxVideoState`** or add **`GfxImageBank`**:
  - Array of **`GfxRasterSurface`** { `kind`, `w`, `h`, `stride`, `owned_ptr`, `bytes` }.
- Surface `0` = **alias** to existing **`bitmap[]`** when `SCREEN 1`.

### 9.2 Native (Raylib)

- **COPY** is **CPU**; optional **future:** upload **RGBA** surface to **Texture2D** for fast preview (not required for Phase 1).

### 9.3 WASM

- Surfaces live in **Wasm linear memory**; **`gfx_canvas`** compositor reads **visible** bitmap as today.
- **Export:** encode PNG in WASM **or** export **raw** and PNG-encode in **JS** (smaller WASM binary) — **tradeoff decision**.

### 9.4 Threading

- Same rules as sprites: **no OpenGL** from worker if **basic-gfx** worker thread; **COPY** is **CPU-only** → safe on worker **if** single-writer discipline holds.

---

## 10. Testing

- **Golden tests:** Small fixed patterns **COPY** and compare byte arrays (`tests/image_copy_test.c`).
- **BASIC regressions:** `tests/image_copy.bas` — deterministic output hash or **PEEK** sample points.
- **WASM:** Playwright: run program, **export**, compare **PNG** checksum or dimensions.

---

## 11. Open decisions (need your input)

### Blitter / surfaces

1. **Keyword prefix:** `IMAGE` vs `BITMAP` vs `SURFACE`.
2. **Rect syntax:** `w,h` vs `x1,y1,x2,y2` only.
3. **`TOSPRITE` from 1 bpp:** **two-colour** fixed vs **palette** from PETSCII.
4. **PNG in WASM:** encode in C vs JS.
5. **Max surfaces / max WxH** on WASM (heap).

### Periodic timers (§6)

6. **Dispatch point:** once per **gfx frame** vs **between statements** (cost/semantics).
7. **API shape:** `TIMER … GOSUB` vs **`CALL`** vs **polling `TIMERDUE` only**.
8. **Units:** milliseconds vs **1/60 s** jiffies (or support both).
9. **Terminal build:** timers **on** (wall-clock) vs **GFX-only** / error.

---

## 12. Summary

This spec aims for **honest parity** with **“screen copy + grab region + work buffer”** patterns from **AMOS/STOS**, not hardware emulation. **Phase 1** (**off-screen 1 bpp + `IMAGE COPY`**) unlocks most **editor-in-BASIC** value with **manageable** scope on **CLI and WASM**. **Export** and **RGBA** follow once the **surface allocator** and **COPY** semantics are proven.

**Periodic timers (§6)** are the proposed substitute for **AMAL-style** background animation: **VB `Timer`-like** or **IRQ-light** scheduling into **ordinary BASIC** (`GOSUB` / procedures), with **cooperative** dispatch and **WASM-safe** rules — orthogonal to blitter phases but **documented here** for the same **Amiga-era tool** story (starfield + `INPUT` in the foreground).

---

*Document version: 0.2 — draft*
