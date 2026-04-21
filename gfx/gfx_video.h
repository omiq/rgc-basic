/* gfx_video.h - Graphics/video memory model for RGC-BASIC gfx builds.
 *
 * This module is deliberately raylib-free and purely in-memory so it can be
 * tested headless. A separate front-end (e.g. gfx_raylib.c) can render from
 * this state.
 */

#ifndef GFX_VIDEO_H
#define GFX_VIDEO_H

#include <stdint.h>
#include <stddef.h>

/* Virtual address layout (C64-inspired, but not a full emulator). */
#define GFX_TEXT_BASE   0x0400u  /* screen RAM: 1000 bytes (40x25) or 2000 (80x25) */
#define GFX_TEXT_SIZE   2000u

#define GFX_COLOR_BASE  0xD800u  /* colour RAM: 1000 bytes (40x25) or 2000 (80x25) */
#define GFX_COLOR_SIZE  2000u

#define GFX_CHAR_BASE   0x3000u  /* 256 chars * 8 bytes = 2048 bytes */
#define GFX_CHAR_SIZE   (256u * 8u)

/* Keyboard state (host-provided): 256 bytes.
 * Currently mapped as ASCII-like key indices (e.g. 'A' = 65) for simple
 * polling from BASIC via PEEK. Non-zero means "down". */
#define GFX_KEY_BASE    0xDC00u
#define GFX_KEY_SIZE    256u

/* Simple monochrome bitmap: 320x200, 1 bit per pixel. */
#define GFX_BITMAP_BASE 0x2000u
#define GFX_BITMAP_WIDTH  320u
#define GFX_BITMAP_HEIGHT 200u
#define GFX_BITMAP_BYTES  ((GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT) / 8u)

/* Display mode for basic-gfx (SCREEN 0..4). */
#define GFX_SCREEN_TEXT    0u
#define GFX_SCREEN_BITMAP  1u
#define GFX_SCREEN_RGBA    2u
#define GFX_SCREEN_INDEXED 3u   /* 320x200 8bpp palette-indexed */
#define GFX_SCREEN_RGBA_HI 4u   /* 640x400 RGBA (QB64-style desktop canvas) */

/* 32-bit RGBA bytes per pixel for SCREEN 2 / Blitter Phase 2.
 * Kept as the default heap size when SCREEN 2 is activated; SCREEN 4
 * reallocates the plane to 640x400 via gfx_rgba_alloc. */
#define GFX_RGBA_BYTES    (GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT * 4u)

#define GFX_RGBA_HI_W     640u
#define GFX_RGBA_HI_H     400u

/* Multi-plane screen buffers (AMOS-style). Slot 0 is always the inline
 * `bitmap[]`; slot 1 is the inline `bitmap_show[]` used by DOUBLEBUFFER;
 * slots 2..GFX_MAX_SCREEN_BUFFERS-1 are caller-allocated via
 * `SCREEN BUFFER n`. BASIC writes land in whichever slot is currently
 * the draw target (`screen_draw`); the renderer samples the slot
 * selected by `screen_show`. */
#define GFX_MAX_SCREEN_BUFFERS 8u

typedef struct GfxVideoState {
    /* Virtual POKE/PEEK bases (defaults match C64-style layout). Regions may overlap in
     * 16-bit space; gfx_peek() uses fixed priority (keyboard before colour when ranges
     * overlap — see gfx_peek in gfx_video.c). */
    uint16_t mem_text;
    uint16_t mem_color;
    uint16_t mem_char;
    uint16_t mem_key;
    uint16_t mem_bitmap;
    uint8_t screen[GFX_TEXT_SIZE];          /* Screen codes (40x25 or 80x25) */
    uint8_t color[GFX_COLOR_SIZE];          /* Foreground colour indices (0-15 per cell) */
    uint8_t bgcolor[GFX_COLOR_SIZE];        /* Per-cell background colour indices (0-15). Set by PRINT, PAPER, CLS. */
    uint8_t chars[GFX_CHAR_SIZE];           /* Character ROM / UDGs */
    uint8_t bitmap[GFX_BITMAP_BYTES];       /* 320x200 1bpp bitmap — BASIC writes here */
    uint8_t bitmap_show[GFX_BITMAP_BYTES];  /* Double-buffer front: renderer reads this when
                                             * `double_buffer` is 1. VSYNC memcpys bitmap ->
                                             * bitmap_show. When `double_buffer` is 0 the
                                             * renderer reads bitmap[] directly for legacy
                                             * "draw-as-you-go" behaviour. */
    /* Per-pixel colour index (0..15) companion to `bitmap`. Every set-pixel
     * write stamps the current `bitmap_fg` here so programs can change
     * `COLOR` between stamps and each stamp keeps its own colour — the
     * renderer reads this byte instead of the global `bitmap_fg` register
     * when compositing a lit pixel. Cleared to 0 at init; `gfx_video_bitmap_clear`
     * zeroes it alongside `bitmap`. */
    uint8_t bitmap_color[GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT];
    uint8_t bitmap_color_show[GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT];
    uint8_t key_state[256];                 /* Simple keyboard state, 1 = down */
    uint8_t key_queue[64];                  /* Keypress FIFO (bytes), for INKEY$ */
    uint8_t key_q_head;
    uint8_t key_q_tail;
    uint32_t ticks60;                       /* 60 Hz tick counter (TI), wraps at 24h */
    uint8_t bg_color;                       /* Background colour index (0-15) */
    uint8_t bitmap_fg;                      /* Hi-res bitmap “pen” (0-15), COLOR in gfx build */
    uint8_t double_buffer;                  /* 0 = single-buffered (renderer reads bitmap[] live),
                                             * 1 = double-buffered (renderer reads bitmap_show[]).
                                             * Set via `DOUBLEBUFFER ON` / `DOUBLEBUFFER OFF`.
                                             * Only affects the bitmap plane; cell list (SPRITE
                                             * STAMP / TILEMAP DRAW) is always double-buffered. */
    uint8_t charset_lowercase;              /* 0=upper/graphics, 1=lower/upper */
    uint8_t charrom_family;                 /* 0=C64 ROM, 1=PET-style alt (pet_uppercase/lowercase_64c) */
    uint8_t cols;                           /* 40 or 80; columns per row */
    uint8_t screen_mode;                    /* GFX_SCREEN_TEXT or GFX_SCREEN_BITMAP */
    /* Viewport scroll (pixels): content is shifted left/up by these amounts when compositing. */
    int16_t scroll_x;
    int16_t scroll_y;
    /* Multi-plane screen buffer table. Slot 0 always points at `bitmap[]`;
     * slot 1 always points at `bitmap_show[]`; slots 2..7 are NULL until
     * SCREEN BUFFER n allocates a GFX_BITMAP_BYTES block on heap.
     * `screen_buffer_owned[n]` is 1 when we malloc'd the slot (needs free). */
    uint8_t *screen_buffers[GFX_MAX_SCREEN_BUFFERS];
    uint8_t  screen_buffer_owned[GFX_MAX_SCREEN_BUFFERS];
    uint8_t  screen_draw;                   /* slot index: BASIC writes target this plane */
    uint8_t  screen_show;                   /* slot index: renderer samples this plane */
    /* SCREEN 2 / SCREEN 4 — 32-bit RGBA plane. Heap-allocated on first
     * entry; NULL when RGBA mode has never been used. Layout: tightly
     * packed rgba_w × rgba_h RGBA8 rows.
     *   SCREEN 2 → 320 × 200 (256000 bytes, classic retro canvas)
     *   SCREEN 4 → 640 × 400 (1.024 MB, QB64-style desktop canvas)
     * `bitmap_rgba_show` is the DOUBLEBUFFER companion; `rgba_w/h` track
     * the current allocation so every helper/render path can pick up
     * the right dimensions when a program switches between SCREEN 2
     * and SCREEN 4. All colour comes straight from `pen_r/g/b/a`; no
     * palette lookup. */
    uint8_t  *bitmap_rgba;
    uint8_t  *bitmap_rgba_show;
    uint16_t  rgba_w;
    uint16_t  rgba_h;
    uint8_t   pen_r, pen_g, pen_b, pen_a;    /* RGBA pen for SCREEN 2/4 draws */
    uint8_t   bgrgba_r, bgrgba_g, bgrgba_b, bgrgba_a;  /* RGBA clear colour */
} GfxVideoState;

/* Advance 60 Hz jiffy counter (TI / TI$); wraps every 24h like C64. */
#define GFX_TICKS60_WRAP 5184000u
void gfx_video_advance_ticks60(GfxVideoState *s, uint32_t delta_ticks);

/* Initialise state to a clean default (all zeros). */
void gfx_video_init(GfxVideoState *s);

/* Apply a named layout: "c64" (default) or "pet" (screen at $8000, etc.). Returns 0 on success. */
int gfx_video_apply_memory_preset(GfxVideoState *s, const char *preset);

/* Set all bases at once (e.g. after validation). Returns 0 on success, -1 if ranges overlap or overflow 64K. */
int gfx_video_set_memory_bases(GfxVideoState *s,
    uint16_t text, uint16_t color, uint16_t chr, uint16_t key, uint16_t bitmap);

typedef enum {
    GFX_MEM_TEXT = 0,
    GFX_MEM_COLOR,
    GFX_MEM_CHAR,
    GFX_MEM_KEY,
    GFX_MEM_BITMAP
} GfxMemRegion;

/* Change one region’s base address (hex-friendly programs often use one custom screen address). */
int gfx_video_set_memory_base(GfxVideoState *s, GfxMemRegion region, uint32_t base);

/* Clear all video RAM (screen, colour, chars, bitmap) but leave input state. */
void gfx_video_clear(GfxVideoState *s);

/* Reset keyboard state. */
void gfx_video_clear_keys(GfxVideoState *s);

/* Virtualised PEEK/POKE for video-related address ranges.
 *
 * Regions may overlap in 16-bit space (e.g. C64 colour vs keyboard).
 *
 * RESOLUTION ORDER (fixed — do not reorder in gfx_video.c):
 *   1. text screen
 *   2. KEYBOARD  ← before colour RAM; GFX_KEY_BASE (0xDC00) is inside
 *                  the colour window [0xD800, 0xDFD0) so keyboard must
 *                  win the tie-break or PEEK(56320+n) returns colour data.
 *   3. colour RAM
 *   4. charset
 *   5. bitmap
 *
 * Addresses outside the defined ranges currently read as 0 and ignore writes.
 * This is intentional: the graphics build only defines semantics for its
 * own virtual “hardware” and leaves everything else to the core interpreter.
 */
uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr);
void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value);

/* Hi-res bitmap: 320×200, row-major, 40 bytes per row, MSB = left pixel in each byte. */
int gfx_bitmap_get_pixel(const GfxVideoState *s, unsigned x, unsigned y);

/* Read the pixel the renderer should display. With double-buffer off
 * this just reads bitmap[]; with it on, it reads bitmap_show[] so
 * in-flight draws stay hidden until the next VSYNC. */
int gfx_bitmap_get_show_pixel(const GfxVideoState *s, unsigned x, unsigned y);

/* Per-pixel colour index (0..15) the renderer should display for the
 * given (x, y). Returns 0 when the pixel is out of range or unset —
 * caller should first check `gfx_bitmap_get_show_pixel` to decide
 * whether to draw at all. Reads `bitmap_color_show` when
 * `double_buffer` is on and draw/show slots differ. */
int gfx_bitmap_get_show_color(const GfxVideoState *s, unsigned x, unsigned y);

/* 256-entry palette, writable. First 16 entries default to the C64
 * hex values; 16..255 default to an HSV rainbow so SCREEN 3 has
 * something to draw before PALETTESET touches them. All entries
 * RGBA (alpha=255 on reset). Shared by every screen mode:
 *   SCREEN 1 bitmap_color[] stores 4-bit indices (0..15) — masks
 *     to the first 16 entries.
 *   SCREEN 2 looks up via COLOR n -> RGBA translation.
 *   SCREEN 3 bitmap_color[] stores full 8-bit indices (0..255).
 * PALETTESET / PALETTERESET immediately affect all of them. */
extern uint8_t gfx_c64_palette_rgb[256][4];

/* Reset palette: entries 0..15 back to C64 defaults, 16..255 back
 * to the HSV rainbow generated on init. */
void gfx_palette_reset(void);

/* Rotate palette entries [first..last] (inclusive, 0..255) by `step`.
 * Positive step shifts entries forward (toward higher indices),
 * negative rotates backward. step==0 is a no-op. Indices outside
 * the range are untouched. Clamps first/last into 0..255. */
void gfx_palette_rotate(int first, int last, int step);

/* Plain-text .pal I/O.
 *
 * Format: up to 256 lines of "R G B [A]" with decimal 0..255
 * values (whitespace-separated). Lines starting with '#' are
 * comments; blank lines ignored. JASC-PAL header "JASC-PAL /
 * 0100 / <count>" is auto-detected and skipped.
 *
 * Load: populates the live palette in order. Missing entries
 * left untouched (so a 16-entry .pal retunes only 0..15).
 * Extras beyond 256 are dropped.
 *
 * Save: writes exactly 256 entries + a short "# " header.
 *
 * Returns 0 on success, -1 on error. */
int gfx_palette_load_file(const char *path);
int gfx_palette_save_file(const char *path);

/* SCREEN 2 RGBA plane helpers ---------------------------------------- */

/* Allocate the RGBA draw + show planes on demand. Called by SCREEN 2 on
 * first entry; idempotent. Returns 0 on success, -1 on alloc failure. */
/* Allocate (or reallocate) the RGBA plane at the requested dimensions.
 * Safe to call repeatedly — when the requested size matches what's
 * already allocated this is a no-op; otherwise the old buffer is freed
 * and a fresh zeroed buffer is installed along with its show twin.
 * Records w/h on the state for the helpers + renderer to pick up. */
int gfx_rgba_alloc(GfxVideoState *s, unsigned w, unsigned h);

/* Fill the RGBA draw plane with the current bg RGBA. */
void gfx_rgba_clear(GfxVideoState *s);

/* Set a single RGBA pixel using the current pen (pen_r/g/b/a). Clipped. */
void gfx_rgba_set_pixel(GfxVideoState *s, int x, int y);

/* Bresenham line in RGBA using current pen. */
void gfx_rgba_line(GfxVideoState *s, int x0, int y0, int x1, int y1);

/* Fill a rectangle with the current pen (inclusive bounds). */
void gfx_rgba_fill_rect(GfxVideoState *s, int x0, int y0, int x1, int y1);

/* Read the RGBA the renderer should display; when double_buffer is on
 * reads bitmap_rgba_show, else bitmap_rgba. Stores into out[4]. Returns
 * 1 on success, 0 if the plane isn't allocated. */
int gfx_rgba_get_show_pixel(const GfxVideoState *s, unsigned x, unsigned y, uint8_t out[4]);

/* Copy RGBA draw → show (VSYNC flip). Caller should first verify
 * double_buffer is on and slots differ. */
void gfx_rgba_flip(GfxVideoState *s);

/* Stamp a glyph from `chars[]` into the RGBA plane using the current
 * pen. Transparent background (only lit bits written). */
void gfx_rgba_stamp_glyph_px(GfxVideoState *s, int x, int y, uint8_t screencode);
void gfx_rgba_stamp_glyph_px_scaled(GfxVideoState *s, int x, int y,
                                    uint8_t screencode, int scale);

/* Copy the draw plane to the show plane. Called by VSYNC (and only
 * does work when `double_buffer` is 1 and draw != show). Safe to call
 * before any draws to force an initial promote. */
void gfx_video_bitmap_flip(GfxVideoState *s);

/* Return the current draw / show plane pointer. Never NULL for slot 0
 * after gfx_video_init. Caller should not free. */
uint8_t       *gfx_video_draw_plane(GfxVideoState *s);
const uint8_t *gfx_video_show_plane(const GfxVideoState *s);

/* SCREEN BUFFER n — allocate slot `n` (2..7). Slots 0 and 1 are
 * always present and cannot be reallocated. Returns 0 on success,
 * -1 if slot is out of range or malloc fails. Re-allocating an
 * already-owned slot is a no-op (returns 0). */
int  gfx_video_screen_buffer_alloc(GfxVideoState *s, int slot);

/* SCREEN FREE n — release slot `n` (2..7). Refuses slots 0/1, the
 * current draw slot, or the current show slot. Returns 0 on success. */
int  gfx_video_screen_buffer_free(GfxVideoState *s, int slot);

/* SCREEN DRAW n / SCREEN SHOW n — retarget writes / reads. Fails
 * if slot is unallocated. Returns 0 on success. */
int  gfx_video_screen_set_draw(GfxVideoState *s, int slot);
int  gfx_video_screen_set_show(GfxVideoState *s, int slot);

/* SCREEN SWAP a, b — atomic draw=a, show=b (both slots must exist). */
int  gfx_video_screen_swap(GfxVideoState *s, int draw_slot, int show_slot);

/* SCREEN COPY src, dst — memcpy buffer[src] into buffer[dst]. Both
 * slots must be allocated. */
int  gfx_video_screen_copy(GfxVideoState *s, int src, int dst);
/* Set (on=1) or clear (on=0) one pixel; coordinates outside the bitmap are ignored. */
void gfx_bitmap_set_pixel(GfxVideoState *s, int x, int y, int on);
/* Bresenham line; each point is clipped (same semantics as PSET/PRESET). */
void gfx_bitmap_line(GfxVideoState *s, int x0, int y0, int x1, int y1, int on);

/* Clear the 320x200 1bpp bitmap plane to all-zero. Leaves the text plane
 * and character RAM alone. Equivalent to memset(s->bitmap, 0, ...) but
 * named so callers make their intent explicit (BITMAPCLEAR, CHR$(147) in
 * bitmap mode, etc.). */
void gfx_video_bitmap_clear(GfxVideoState *s);

/* Stamp an 8x8 glyph from the active character set (s->chars[]) into the
 * bitmap plane at character cell (col, row). Cells are 8x8 pixels; (0, 0)
 * is top-left, col range [0, 39], row range [0, 24].
 *
 * screencode indexes s->chars[] at byte offset screencode*8.
 *
 * solid_bg:
 *   0 — transparent paper: OR the glyph bits into bitmap[] (leaves
 *       existing pixels in the cell intact where the glyph has 0 bits).
 *   1 — opaque paper: overwrite the 8x8 cell with the glyph bits (clears
 *       cleared pixels too).
 *
 * Out-of-range cells are silently clipped (no-op). This is the primitive
 * used by the character-set-in-bitmap-mode rendering path; Fonts for
 * DRAWTEXT will use a separate helper when that lands. */
void gfx_video_bitmap_stamp_glyph(GfxVideoState *s,
                                  int col, int row,
                                  uint8_t screencode,
                                  int solid_bg);

/* Pixel-space glyph stamp — arbitrary (x, y) in pixel coordinates
 * rather than character-cell row/col. Transparent background (OR).
 * Used by the DRAWTEXT statement. Identical to the _scaled variant
 * with scale=1. */
void gfx_video_bitmap_stamp_glyph_px(GfxVideoState *s,
                                     int x, int y,
                                     uint8_t screencode);

/* Same as gfx_video_bitmap_stamp_glyph_px but each source glyph pixel
 * expands to a `scale x scale` block. Clipped to the bitmap; scale
 * clamped to [1, 8]. Used by DRAWTEXT x, y, text$, scale. */
void gfx_video_bitmap_stamp_glyph_px_scaled(GfxVideoState *s,
                                            int x, int y,
                                            uint8_t screencode,
                                            int scale);

/* Scroll the bitmap plane up by one character cell (8 pixel rows).
 * The top 8 pixel rows are discarded; the bottom 8 pixel rows are
 * cleared to zero. Used by PRINT-in-bitmap-mode when a newline
 * would advance past row 24. Pure memmove, no overlap with text
 * plane or chars[]. */
void gfx_video_bitmap_scroll_up_cell(GfxVideoState *s);

/* ----------------------------------------------------------------
 * IMAGE DRAW slot retarget (2.1).
 *
 * Swaps the live RGBA draw target so every SCREEN 2 / SCREEN 4
 * primitive (LINE, FILLRECT, CIRCLE, DRAWTEXT, PSET, POLYGON, …)
 * writes into an off-screen IMAGE CREATE surface instead of the
 * visible framebuffer. All primitives read `s->bitmap_rgba` /
 * `rgba_w` / `rgba_h`, so we just repoint the triple to the
 * IMAGE slot's RGBA + w/h; BASIC's `IMAGE DRAW 0` restores the
 * saved triple.
 *
 * Semantics:
 *   * No-op on non-RGBA screens (SCREEN 0 / 1 / 3). Returns -1.
 *   * Re-entrant: calling with a new slot while already retargeted
 *     keeps the original framebuffer saved; only `IMAGE DRAW 0`
 *     restores. Nested saves not supported.
 *   * SPRITE STAMP / DRAWSPRITE / tilemap verbs are unaffected —
 *     those have their own queue and aren't primitive-buffer
 *     writers.
 *
 * `gfx_image_draw_target_slot()` returns the current active slot
 * (0 = live framebuffer), handy for runtime errors and introspection.
 * ---------------------------------------------------------------- */

int  gfx_set_image_draw_target(int slot);    /* 0 = restore live */
int  gfx_image_draw_target_slot(void);

/* ----------------------------------------------------------------
 * Scroll zones + per-scanline warp (2.1 scroll system).
 *
 * Two stacked mechanisms applied during the RGBA composite (SCREEN 2
 * and SCREEN 4 only for now):
 *
 *   1. Per-scanline horizontal offset — each visible pixel row has
 *      its own `dx`. The renderer reads the source pixel at column
 *      `(x + dx) mod rgba_w` and wraps, so one row of bitmap appears
 *      shifted by `dx` pixels without BASIC ever touching the buffer.
 *      Classic Amiga copper-list / raster-line tricks: water ripple,
 *      flag wave, heat haze, CRT jitter.
 *
 *   2. Rectangular scroll zones — a named y..y+h-1 band with its own
 *      persistent dx. Simpler to drive from BASIC than line-by-line
 *      (one zone dx advance per frame ≈ whole message strip scrolls).
 *      Applied before per-line offsets, so per-line warp can layer on
 *      top of a scrolling zone. Up to GFX_MAX_SCROLL_ZONES active at
 *      once.
 *
 * No dynamic allocation — both tables live on `GfxVideoState`. The
 * composite path skips the rewrite loop entirely when no zone is
 * active AND no scanline has a non-zero dx (the common case). See
 * `gfx_scroll_is_active` for the fast-path flag.
 * ---------------------------------------------------------------- */

#define GFX_MAX_SCROLL_ZONES 8u

typedef struct GfxScrollZone {
    int16_t  y;      /* top row (inclusive) */
    int16_t  h;      /* height in pixel rows */
    int32_t  dx;     /* horizontal offset applied to every row of the zone */
    uint8_t  active; /* 1 = zone in use, 0 = free slot */
} GfxScrollZone;

/* Declare / update a scroll zone. `id` is 1..GFX_MAX_SCROLL_ZONES-1
 * (slot 0 reserved for "no zone"); y/h clipped at composite time. */
int  gfx_scroll_zone_set(int id, int y, int h);
int  gfx_scroll_zone_advance(int id, int dx);   /* add dx to zone's running offset */
int  gfx_scroll_zone_reset(int id);             /* zero the offset, keep rect */
int  gfx_scroll_zone_clear(int id);             /* release the zone slot */

/* Per-scanline absolute dx for a single row. y clipped to the current
 * RGBA plane height at composite time. */
int  gfx_scroll_line_set(int y, int dx);
void gfx_scroll_line_reset(void);               /* zero every row */

/* Wipe every zone + every per-line dx. */
void gfx_scroll_reset_all(void);

/* Fast-path check used by the composite: true when at least one zone
 * has dx != 0 or any scanline entry is non-zero. When false the
 * renderer can skip the rewrite loop entirely. */
int  gfx_scroll_is_active(void);

/* Read out the effective dx for row y (zone + per-line stacked).
 * Returns 0 when both layers are zero or the row is out of range. */
int  gfx_scroll_effective_dx(int y, int rgba_h);

#endif /* GFX_VIDEO_H */

