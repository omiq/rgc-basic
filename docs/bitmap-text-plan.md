# Text in bitmap mode — planning notes

## Problem

In `SCREEN 0` (text mode) `PRINT`, `LOCATE`, `TEXTAT`, `COLOR`, `BACKGROUND`,
`CHR$(147)` all work against the text plane (`screen[]` + `color[]`). In
`SCREEN 1` (320×200 bitmap mode, 8000 bytes at `$2000`) those same statements
currently write to the text plane but nothing renders them — the bitmap plane
is what the user sees, and it has no glyphs on it. Programs that PRINT a
HUD, status line, or score in bitmap mode silently "do nothing".

## Decision

Two orthogonal APIs:

1. **Existing text statements work in both modes** — `PRINT`, `LOCATE`,
   `TEXTAT`, `COLOR`, `BACKGROUND`, `CURSOR`, `CHR$(147)`. Character-cell
   addressing (40×25 or 80×25). Same keyword, different rendering path
   per `screen_mode`. C64-faithful; programs that PRINT a HUD stay
   portable across modes.
2. **New `DRAWTEXT` statement for pixel-space rendering.** Explicit
   `x, y` in pixels, optional fg/bg colours, optional Font slot.
   Bitmap-mode only. No pretence of C64 compatibility — this is the
   modern escape hatch for arbitrary placement, colour, and typography.

One API for compatibility, one for expression. No parallel `BITMAPPRINT`
family; that would double the keyword surface for no real gain.

## Terminology — "character set" vs "Font"

These are deliberately distinct concepts in RGC-BASIC, and the spec
uses the two terms strictly.

**character set** (lowercase) — the C64-faithful world. Fixed 8×8
cells, exactly 256 glyphs indexed by PETSCII screencode, one active
set at a time (upper/graphics or upper/lower). Drives `PRINT`,
`LOCATE`, `TEXTAT`, `COLOR`, `BACKGROUND`, `CURSOR`, `CHR$(147)` and
the 40×25 / 80×25 grid. Obeys all PETSCII control-code rules
(`CHR$(13)` wraps, `CHR$(147)` clears, etc.). Lives at the existing
C64 memory locations. Swapped via the existing chargen mechanism.
In bitmap mode, the character-set glyphs are stamped into `bitmap[]`
at cell positions — no other behaviour changes.

**Font** (capital F) — a new, parallel concept that only `DRAWTEXT`
sees. Arbitrary width × height (width a multiple of 8), arbitrary
glyph count, indexed however the Font file says (ASCII, a
game-specific symbol table, whatever the artist chose). Carries no
PETSCII semantics, no control-code behaviour, no implicit colour
memory, no cursor, no scrolling. Lives in Font slots in
`GfxVideoState`, loaded via `LOADFONT slot, "file.rgcfont"`. Slot 0
is a built-in default Font so `DRAWTEXT` works before any `LOADFONT`.

**Rules that fall out of this split:**

- `DRAWTEXT` is PETSCII-free. Bytes in the string are raw indices
  into the Font's glyph table. `CHR$(147)` inside a `DRAWTEXT`
  string draws glyph 147 of the Font — it does **not** clear the
  screen. `CHR$(13)` draws glyph 13 — it does **not** wrap. If the
  programmer wants a newline they call `DRAWTEXT` twice at different
  `y`. This is a feature: `DRAWTEXT` is a pure "stamp these glyph
  indices at this pixel" primitive, predictable for game code.
- Character sets and Fonts don't share storage, don't share structs,
  don't share loaders. `LOADFONT` only touches Font slots. The
  existing chargen swap mechanism only touches the active character
  set. Neither can corrupt the other.
- The `RGCF` headered format only describes Fonts. Character sets
  keep their raw 2KB layout because they're always 8×8×256 by
  definition — that constraint is what makes them character sets
  rather than Fonts.
- Size / scale / weight (see "Sizes and scales") apply only to
  Fonts. Character sets are forever 8×8 at scale 1.

---

## Part 1 — Text statements in bitmap mode

### Rendering path

When `gfx_vs->screen_mode == GFX_SCREEN_BITMAP`, a text statement that
would normally write a screencode to `screen[r*COLS+c]` instead blits
the 8×8 glyph for that screencode from `pet_style_64c_data` into
`bitmap[]` at pixel position `(c*8, r*8)`. The text plane is *not*
updated — bitmap mode has no visible text plane, so keeping a shadow
copy just wastes cycles and invites inconsistency.

One helper:

```c
/* Stamp an 8x8 glyph into the bitmap at character cell (col, row).
 * pen = 1 sets bits to foreground, pen = 0 clears (paper).
 * Respects current COLOR (pen) / BACKGROUND (paper) — bitmap is 1bpp,
 * so only pen matters for set bits; paper is applied by zeroing the
 * cell first when the caller wants a solid background. */
static void bitmap_stamp_glyph(GfxVideoState *s,
                               int col, int row,
                               uint8_t screencode,
                               int solid_bg);
```

### Touch points in basic.c

Each of these statements gains a `screen_mode` check at the point where
it currently writes to `screen[]` / `color[]`:

| Statement       | Text-mode behaviour               | Bitmap-mode behaviour |
|-----------------|-----------------------------------|------------------------|
| `PRINT`         | write screencodes to `screen[]`   | stamp glyphs to `bitmap[]` at cursor cell, advance cursor |
| `TEXTAT x, y, s`| write screencodes at cell (x, y)  | stamp glyphs at cell (x, y) |
| `LOCATE r, c`   | set text cursor                   | set text cursor (same state, used by `PRINT`) |
| `COLOR n`       | set pen                           | set pen (used by next glyph stamp / PSET) |
| `BACKGROUND n`  | set paper                         | set paper (used when solid_bg requested) |
| `CURSOR ON/OFF` | toggle cursor blink               | no-op in bitmap mode (no cursor to blink) |
| `CHR$(147)`     | clear text plane                  | clear bitmap plane (`memset(bitmap, 0, 8000)`) |

`CHR$(147)` handling lives inside the `PRINT` character loop — when the
current mode is bitmap, it calls the same code path as `BITMAPCLEAR`.

### Scrolling

Text mode: `PRINT` past row 25 scrolls the text plane up one cell-row.
Bitmap mode: `PRINT` past row 25 scrolls the bitmap plane up 8 pixel
rows (`memmove` the top 192 rows up by 8, zero the bottom 8). Same
visual effect, different plane. `SCROLL dx, dy` stays explicit and
independent.

### Colour RAM

Bitmap mode at 320×200 is 1bpp — no per-cell colour. `COLOR n` still
sets the pen used by subsequent glyph stamps and `PSET`/`LINE`.
Per-cell writes to `color[]` ($D800+) still land in the array but
aren't rendered. Documented as-is; no attempt to emulate VIC-II
multicolour bitmap mode.

### Test coverage

Extend `tests/gfx_video_test.c` with:

- `PRINT "A"` in bitmap mode sets the expected bits in `bitmap[0..7]`
  matching the 'A' glyph from `pet_style_64c_data`.
- `CHR$(147)` in bitmap mode zeroes `bitmap[]` and leaves `screen[]`
  untouched.
- `LOCATE 2, 3 : PRINT "X"` in bitmap mode stamps the glyph at byte
  offset `(1*8*40) + 2 = 322` (row 1, col 2 in cell space = pixel row 8,
  col 16; `(y/8)*320 + x` -> `(8/8)*320 + 16 = 336`, offset inside row is
  `x & 7`; double-check the bitmap byte layout against `gfx_poke` math).
- Round-trip: switch SCREEN 1 → PRINT → SCREEN 0 → text plane is
  unchanged from whatever was there before, confirming bitmap PRINT
  did not touch `screen[]`.

### Canvas WASM parity

The canvas renderer (`gfx/gfx_canvas.c` / `wasm_gfx_rgba_ptr`) already
reads from `bitmap[]` when `screen_mode == GFX_SCREEN_BITMAP`. Stamping
glyphs into `bitmap[]` is therefore automatically visible on the WASM
side — no JS changes required. Add a Playwright case in
`tests/wasm_browser_canvas_test.py` that does `SCREEN 1 : PRINT "HI"`
and screenshot-asserts non-zero pixels at the expected region.

---

## Part 2 — `DRAWTEXT` (pixel-space text)

### Syntax

```basic
DRAWTEXT x, y, text$
DRAWTEXT x, y, text$, fg
DRAWTEXT x, y, text$, fg, bg
DRAWTEXT x, y, text$, fg, bg, font_slot
DRAWTEXT x, y, text$, fg, bg, font_slot, scale
```

- `x, y` — pixel position of the top-left of the first glyph. Integers,
  clipped to the bitmap extents.
- `text$` — string. No cursor state; does not advance or wrap. Callers
  who want wrapping call `DRAWTEXT` in a loop.
- `fg` — foreground colour index (0–15, C64 palette). Optional; defaults
  to current `COLOR`.
- `bg` — background colour index (0–15) OR `-1` for transparent.
  Optional; default transparent.
- `font_slot` — integer 0..N-1 selecting a loaded Font. Optional;
  default 0 (built-in default Font, 8×8).
- `scale` — integer ≥1, nearest-neighbour pixel-doubling applied at
  render time. Optional; default 1. See "Sizes and scales" below.

### Sizes and scales

Font size in bitmap mode is worth thinking through carefully — it
ripples into struct layout, on-disk format, and the `LOADFONT`
contract. The clean answer is to separate two independent concerns.
(This applies only to Fonts; character sets are always 8×8 at
scale 1.)

**1. Native glyph dimensions** — intrinsic to the Font artwork.
Stored per-slot. A 16×16 Font has its own 8192-byte glyph table,
not a scaled-up 8×8. Different sizes = different Fonts = different
slots. This is how you get sleek 12-tall sans-serif HUD text that
isn't just a blown-up 8×8.

**2. Render-time scale** — integer pixel-doubling applied by the
renderer at draw time. `scale = 2` turns any Font slot into a 2×
version of itself, nearest-neighbour, no new assets. This is how
you get chunky title text from your existing 8×8 Font without
shipping a second Font.

Both compose: `DRAWTEXT 10, 10, "HI", 7, -1, 2, 3` means "slot 2
(e.g. a native 16×16 bold Font), scaled 3×, so each glyph renders
as a 48×48 block". Covers practical needs (HUD, title, score,
damage numbers) without the interpreter having to generate weight
algorithmically — fake-bold from 1bpp glyphs looks terrible, and
weights should ship as separate Font slots with their own artwork.

**Struct / memory impact:**

- `GfxVideoState` gains a `Font fonts[N]` array, where
  `typedef struct { uint8_t *data; uint16_t width, height;
  uint16_t bytes_per_row; uint16_t glyph_count; } Font;`. This
  type is entirely separate from the character-set storage; the
  existing chargen pointers/arrays remain as they are.
- Slot 0 is initialised to the built-in default Font (static
  pointer, never freed). It happens to be 8×8×256 but it is **not**
  the active character set — it's a Font copy used by `DRAWTEXT`.
  Programs that swap character sets do not affect slot 0.
- Non-slot-0 entries hold heap-allocated buffers freed on
  `UNLOADFONT` or interpreter shutdown.
- Loaded Fonts are `glyph_count × (width/8) × height` bytes. An
  8×16 Font with 256 glyphs is 4KB, a 16×16 Font is 8KB, a 16×32
  Font is 16KB — all reasonable for modest slot counts (N = 8
  feels right as a ceiling).
- Width is constrained to multiples of 8 to keep the stamp routine
  simple (byte-aligned rows). 8, 16, 24, 32 are supported; 12 is not.
  Documented.

**Constraints and guardrails:**

- `scale` is an integer ≥1. No fractional scaling (arbitrary resize
  of 1bpp glyphs looks bad and invites blurry filters we don't want).
- `scale × native_width` must fit in the bitmap — clipped at
  rendering, not a runtime error.
- `PRINT`/`LOCATE`/`TEXTAT` in bitmap mode always use the active
  **character set** at 8×8, scale 1. They do not read from Font
  slots at all. Size/scale/Font selection is `DRAWTEXT`-only.
  Programs that need larger text or a different typeface call
  `DRAWTEXT`.
- `DRAWTEXT` never runs its string through PETSCII normalisation.
  The Font is indexed by the raw byte values in `text$`. Control
  codes are glyphs in the Font (or unused slots), not behaviour.

### Font slots

Mirror the sprite-slot model:

```basic
LOADFONT slot, "path.rgcfont"
UNLOADFONT slot
FONTSLOT(path$)   REM future: returns first free slot
```

MVP: `LOADFONT slot, "path.rgcfont"` loads a headered Font file.
Header format (8 bytes):

```
offset  bytes  meaning
0       4      magic "RGCF"
4       1      glyph width (pixels; must be multiple of 8)
5       1      glyph height (pixels)
6       2      glyph count (little-endian; typically 256)
```

Followed by `glyph_count × (width/8) × height` raw bitmap bytes in
the Font's own indexing order — **not** PETSCII screencode order.
Fonts are free of PETSCII entirely; the convention for a given Font
file is whatever its author chose (typical choice: ASCII, byte N =
glyph for codepoint N). Magic bytes let `LOADFONT` reject the wrong
format cleanly and leave room to bump the header later (e.g. a v2
that adds kerning tables or a Unicode lookup side-table).

Character sets (the C64-style chargen used by `PRINT`) stay
headerless and stay PETSCII-indexed. Only Font files carry the
`RGCF` header, and only `LOADFONT` reads them.

**Intermediate — offline converter tool.** Before adding TTF or PNG
parsing *inside* the interpreter, ship a standalone converter that
turns a bitmap-font image into the `.rgcfont` format `LOADFONT`
consumes. Keeps the interpreter's Font loader tiny (header read +
single `fread`) while letting users bring any bitmap Font — edit
glyphs in Aseprite/GIMP/Photoshop, export PNG, convert, load.

Design sketch:

```
tools/pngfont2rgc.c  (or .py)

pngfont2rgc input.png output.rgcfont
  --cell 8x8              (glyph cell size; 8x8, 8x16, 16x16, 16x32, …)
  --grid 16x16            (glyphs per row × rows; default covers 256)
  --threshold 128         (pixels >= threshold → set bit)
  --start 0               (first screencode; default 0)
```

Layout convention: a (cell_w × grid_cols) × (cell_h × grid_rows) PNG
arranged as grid_cols × grid_rows cells in the Font's own indexing
order (typically ASCII: top-left = glyph 0, reading order). At the
default 8×8 cell / 16×16 grid that's a 128×128 PNG covering all 256
codes. Any 1-bit, indexed, or greyscale PNG works; RGB channels
averaged then thresholded. The converter writes the `RGCF` header
based on `--cell` before the bitmap data.

Ships as a native C tool in `tools/` (uses the `stb_image.h` already
in `gfx/` for decoding), plus optional companion `tools/pngfont2rgc.py`
for users who'd rather edit and convert in one script. Documented
with worked examples in `examples/fonts/` (at minimum: 8×8 default,
8×16 slim, 16×16 chunky, 16×16 bold).

TTF rendering inside the interpreter remains a far-future item —
only worth doing if "edit PNG, convert, reload" proves too clunky in
practice.

Built-in slots:

- Slot 0 — built-in default Font (ships as an 8×8×256 copy of the
  PET artwork for convenience, but semantically it is a Font, not
  the active character set; swapping the character set does not
  affect it).
- Slot 1 — reserved for a second built-in (e.g. a slim 8×16 Font)
  if we want one without requiring `LOADFONT`.

### Colour

Because the bitmap plane is 1bpp, `fg` and `bg` only take effect when
the renderer composites bitmap pixels to RGBA. The renderer already
maps `bitmap` bit 1 → `COLOR` pen, bit 0 → `BACKGROUND` paper. For
`DRAWTEXT`, per-call fg/bg needs one of two implementations:

- **MVP:** temporarily override `gfx_vs->pen` / `paper` for the duration
  of the call, then restore. Simple; global pen/paper are already the
  rendering inputs, so zero renderer changes.
- **Later:** per-glyph colour attributes stored in a small attribute
  plane, so multiple `DRAWTEXT` calls with different colours can
  coexist on one frame. Adds state; defer until the MVP proves the
  simpler model is insufficient.

The MVP covers all obvious use cases (score in one colour, banner in
another, full-frame refresh each tick) and doesn't paint us into a
corner.

### `bg = -1` (transparent)

Only set pen bits in `bitmap[]`; leave paper bits untouched. That's
the natural composite over whatever's already drawn.

### `bg >= 0` (solid)

Clear the 8×len rectangle first, then set pen bits. Uses the same
`bitmap_stamp_glyph(solid_bg=1)` path as Part 1.

### Touch points in basic.c

- Add `DRAWTEXT` to the statement dispatcher (new keyword, new handler
  `statement_drawtext`).
- Non-gfx fallback: parse and discard args (follow the POKE pattern
  from 1.6.3 so `IF cond THEN DRAWTEXT ... : stmt` composes cleanly).
- Add `DRAWTEXT`, `LOADFONT`, `UNLOADFONT` to the keyword table and
  the reserved-word list.

### Test coverage

Extend `tests/gfx_video_test.c`:

- `DRAWTEXT 10, 20, "A"` sets expected bits at byte offset
  `(20 * 40) + (10 / 8) = 801`, bits shifted by `10 & 7 = 2`.
- `DRAWTEXT x, y, "A", 7, -1` with pre-drawn pixels in the
  bg-area leaves them untouched (transparent).
- `DRAWTEXT x, y, "A", 7, 0` clears the 8×8 cell before stamping
  (solid bg).
- Out-of-bounds (`x = 320`, `y = 200`) is a runtime error or silent
  clip — pick one and document.

---

## Implementation sequence

Small steps, each landing as its own commit with a test-first change:

1. **Helper + clear semantics.** Add `bitmap_stamp_glyph` and route
   `CHR$(147)` through the `screen_mode` check. Test: bitmap-mode
   `PRINT CHR$(147)` zeroes `bitmap[]`.
2. **`PRINT` / `TEXTAT` in bitmap mode.** Glyph-stamping path under
   `GFX_SCREEN_BITMAP`. Test: `PRINT "A"` lands the A glyph at
   `bitmap[0..7]`. No scroll yet — hitting row 25 is a runtime error
   or silent clip, documented.
3. **Scrolling in bitmap mode.** `memmove` up 8 rows when `PRINT`
   overflows. Test: fill screen then print one extra line, verify
   top 8 rows rolled off.
4. **`DRAWTEXT` with built-in font, MVP colour.** No `LOADFONT` yet.
   Test: pixel-exact placement; transparent vs solid bg.
5. **`LOADFONT` / `UNLOADFONT` — `.rgcfont` with RGCF header.**
   Test: load an 8×8 and an 8×16 Font, `DRAWTEXT … font_slot=1`,
   verify different glyphs render at the correct native size.
6. **Canvas WASM Playwright case.** `SCREEN 1 : PRINT "HI"` and
   `SCREEN 1 : DRAWTEXT 100, 50, "HI", 7` screenshot checks.

Each step is reviewable independently. If we hit a complication in
step 3 (scrolling), we can ship steps 1–2 and defer. Likewise steps
5–6 are optional refinements to the MVP.

---

## Open questions

Resolved by the character-set / Font split:

- ~~PETSCII vs ASCII input for `DRAWTEXT`.~~ Closed: `DRAWTEXT` is
  PETSCII-free; bytes in `text$` are raw Font glyph indices. PETSCII
  normalisation applies only to `PRINT`/`TEXTAT`/`LOCATE`, and in
  bitmap mode those go through the same existing normalisation path
  before `bitmap_stamp_glyph` (inherits from the current PRINT
  character loop — worth one explicit test, but no new logic).
- ~~Cursor rendering in bitmap mode.~~ Closed: the cursor belongs to
  the character-set path. `DRAWTEXT` has no cursor, ever. For
  `PRINT` in bitmap mode, `CURSOR ON` is a no-op in the MVP
  (documented); a future revision can XOR-stamp the cursor glyph on
  blink cadence if anyone asks.

Still open:

- **Wide columns (80-col mode).** 80×25 uses 4×8 glyphs today in
  bitmap-rendered text? Or does 80-col only apply in text mode?
  Character-set scope only — `DRAWTEXT` is pixel-space and
  unaffected. Confirm by reading `gfx_canvas.c`'s cell dimensions
  before implementing step 2.
