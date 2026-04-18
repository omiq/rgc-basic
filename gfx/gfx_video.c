/* gfx_video.c — RGC-BASIC virtual video/input state.
 *
 * ============================================================
 * CRITICAL: gfx_peek() RESOLUTION ORDER — DO NOT CHANGE
 * ============================================================
 * The virtual address map reuses C64-style layout where the
 * keyboard matrix (GFX_KEY_BASE = 0xDC00) sits INSIDE the
 * colour-RAM window (GFX_COLOR_BASE = 0xD800, 2000 bytes).
 *
 *   Colour RAM : [0xD800, 0xD800 + 2000) = [0xD800, 0xDFD0)
 *   Keyboard   : [0xDC00, 0xDC00 + 256)  = [0xDC00, 0xDD00)
 *
 * The keyboard range is entirely contained within colour RAM.
 * Therefore gfx_peek() MUST check keyboard BEFORE colour RAM.
 * If the order is ever swapped, PEEK(56320+n) will return the
 * colour value at that cell (typically 14 after a PRINT"{CLR}")
 * instead of key_state[n], breaking ALL keyboard input in BASIC.
 *
 * BUG HISTORY: In April 2026, a Cursor AI agent rebuilt the
 * WASM from a version of this file that had colour before
 * keyboard in gfx_peek(). Result: PEEK(56320+27) always
 * returned 14 (the foreground colour) so every game loop
 * exited immediately thinking ESC was pressed. The fix is the
 * keyboard check in gfx_peek() below — DO NOT MOVE IT.
 *
 * Resolution order in gfx_peek() must remain:
 *   1. text screen  (0x0400)
 *   2. KEYBOARD     (0xDC00) ← BEFORE colour RAM, always
 *   3. colour RAM   (0xD800)
 *   4. charset      (0x3000)
 *   5. bitmap       (0x2000)
 * ============================================================
 */

#include "gfx_video.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* Regions may overlap in 16-bit address space (like real machines); gfx_peek/poke use a
 * fixed priority: text, KEYBOARD (before colour!), color, char, bitmap.
 * Only require each window to fit in 64K. */
static int memory_layout_valid(const GfxVideoState *s)
{
    uint32_t t0 = s->mem_text;
    uint32_t c0 = s->mem_color;
    uint32_t ch0 = s->mem_char;
    uint32_t k0 = s->mem_key;
    uint32_t b0 = s->mem_bitmap;
    if (t0 + GFX_TEXT_SIZE > 65536u || c0 + GFX_COLOR_SIZE > 65536u ||
        ch0 + GFX_CHAR_SIZE > 65536u || k0 + GFX_KEY_SIZE > 65536u ||
        b0 + GFX_BITMAP_BYTES > 65536u) {
        return 0;
    }
    return 1;
}

int gfx_video_set_memory_bases(GfxVideoState *s,
    uint16_t text, uint16_t color, uint16_t chr, uint16_t key, uint16_t bitmap)
{
    GfxVideoState tmp;
    if (!s) return -1;
    tmp = *s;
    tmp.mem_text = text;
    tmp.mem_color = color;
    tmp.mem_char = chr;
    tmp.mem_key = key;
    tmp.mem_bitmap = bitmap;
    if (!memory_layout_valid(&tmp)) {
        return -1;
    }
    s->mem_text = text;
    s->mem_color = color;
    s->mem_char = chr;
    s->mem_key = key;
    s->mem_bitmap = bitmap;
    return 0;
}

int gfx_video_apply_memory_preset(GfxVideoState *s, const char *preset)
{
    const char *p = preset;
    char buf[16];
    size_t i;
    if (!s || !preset) return -1;
    for (i = 0; i < sizeof(buf) - 1 && p[i] && p[i] != ' ' && p[i] != '\t'; i++) {
        buf[i] = (char)toupper((unsigned char)p[i]);
    }
    buf[i] = '\0';
    if (strcmp(buf, "C64") == 0 || strcmp(buf, "DEFAULT") == 0) {
        return gfx_video_set_memory_bases(s,
            GFX_TEXT_BASE, GFX_COLOR_BASE, GFX_CHAR_BASE, GFX_KEY_BASE, GFX_BITMAP_BASE);
    }
    /* PET-style: screen at $8000; keep other regions clear of $8000–$9E7F (screen+color). */
    if (strcmp(buf, "PET") == 0) {
        return gfx_video_set_memory_bases(s,
            0x8000u, 0x9000u, 0xA000u, 0xDC00u, 0x2000u);
    }
    return -1;
}

int gfx_video_set_memory_base(GfxVideoState *s, GfxMemRegion region, uint32_t base)
{
    uint16_t text, color, chr, key, bitmap;
    if (!s || base > 0xFFFFu) return -1;
    text = s->mem_text;
    color = s->mem_color;
    chr = s->mem_char;
    key = s->mem_key;
    bitmap = s->mem_bitmap;
    switch (region) {
    case GFX_MEM_TEXT:   text = (uint16_t)base; break;
    case GFX_MEM_COLOR:  color = (uint16_t)base; break;
    case GFX_MEM_CHAR:   chr = (uint16_t)base; break;
    case GFX_MEM_KEY:    key = (uint16_t)base; break;
    case GFX_MEM_BITMAP: bitmap = (uint16_t)base; break;
    default: return -1;
    }
    return gfx_video_set_memory_bases(s, text, color, chr, key, bitmap);
}

void gfx_video_advance_ticks60(GfxVideoState *s, uint32_t delta_ticks)
{
    uint64_t t;
    if (!s || delta_ticks == 0) {
        return;
    }
    t = (uint64_t)s->ticks60 + (uint64_t)delta_ticks;
    t %= (uint64_t)GFX_TICKS60_WRAP;
    s->ticks60 = (uint32_t)t;
}

void gfx_video_init(GfxVideoState *s)
{
    if (!s) return;
    memset(s, 0, sizeof(*s));
    s->mem_text = GFX_TEXT_BASE;
    s->mem_color = GFX_COLOR_BASE;
    s->mem_char = GFX_CHAR_BASE;
    s->mem_key = GFX_KEY_BASE;
    s->mem_bitmap = GFX_BITMAP_BASE;
    s->bg_color = 6; /* default C64 blue background */
    memset(s->bgcolor, s->bg_color, sizeof(s->bgcolor));
    s->bitmap_fg = 14; /* default light blue pen (matches text COLOR default) */
    s->charset_lowercase = 1;  /* default lower ROM: ASCII-like upper+lower both render natively; uppercase still shows uppercase (SC 65-90 in lower ROM) */
    s->charrom_family = 0;
    s->cols = 40;    /* 40 or 80; set by basic_set_video from -columns */
    s->key_q_head = 0;
    s->key_q_tail = 0;
    s->ticks60 = 0;
    s->screen_mode = GFX_SCREEN_TEXT;
    s->scroll_x = 0;
    s->scroll_y = 0;
}

void gfx_video_clear(GfxVideoState *s)
{
    if (!s) return;
    memset(s->screen, 0, sizeof(s->screen));
    memset(s->color,  0, sizeof(s->color));
    memset(s->chars,  0, sizeof(s->chars));
    memset(s->bitmap, 0, sizeof(s->bitmap));
}

void gfx_video_clear_keys(GfxVideoState *s)
{
    if (!s) return;
    memset(s->key_state, 0, sizeof(s->key_state));
}

static uint8_t peek_text(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - s->mem_text;
    if (offset < GFX_TEXT_SIZE) {
        return s->screen[offset];
    }
    return 0;
}

static uint8_t peek_color(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - s->mem_color;
    if (offset < GFX_COLOR_SIZE) {
        return s->color[offset];
    }
    return 0;
}

static uint8_t peek_chars(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - s->mem_char;
    if (offset < GFX_CHAR_SIZE) {
        return s->chars[offset];
    }
    return 0;
}

static uint8_t peek_bitmap(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - s->mem_bitmap;
    if (offset < GFX_BITMAP_BYTES) {
        return s->bitmap[offset];
    }
    return 0;
}

static uint8_t peek_keys(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - s->mem_key;
    if (offset < GFX_KEY_SIZE) {
        return s->key_state[offset];
    }
    return 0;
}

/* True if addr is inside [base, base+size). */
static int addr_in(uint16_t addr, uint16_t base, uint16_t size)
{
    return addr >= base && (uint16_t)(addr - base) < size;
}

/* gfx_peek — virtualised PEEK for the gfx address space.
 *
 * !! WARNING: RESOLUTION ORDER IS INTENTIONAL — SEE FILE HEADER !!
 *
 * Two overlap rules apply:
 *
 *  1. The keyboard region (0xDC00–0xDCFF) overlaps colour RAM (0xD800–0xDFCF).
 *     Keyboard MUST be checked first so PEEK(56320+n) returns key_state[n],
 *     not whatever colour is stored at that cell. If you ever see
 *     PEEK(56320+n) returning 14 instead of 0/1, the most likely cause is
 *     that this check order was changed. Fix: ensure the mem_key block is
 *     tested BEFORE the mem_color block, as it is below.
 *
 *  2. The hi-res bitmap region ($2000–$3F3F by default) overlaps the
 *     character RAM region ($3000–$37FF) in the C64-style memory layout.
 *     This faithfully mirrors VIC-II hardware where the same RAM is
 *     interpreted as bitmap pixels OR character glyphs depending on the
 *     current screen mode (the chip's mode chooses the interpretation,
 *     not the address). Therefore for any address inside the overlap,
 *     dispatch is keyed on screen_mode: bitmap wins in GFX_SCREEN_BITMAP,
 *     chars wins in GFX_SCREEN_TEXT.
 */
uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr)
{
    int in_chars, in_bitmap;

    if (!s) return 0;

    /* 1. Text screen RAM (highest priority — not overlapped by anything). */
    if (addr_in(addr, s->mem_text, GFX_TEXT_SIZE))
        return peek_text(s, addr);

    /* 2. KEYBOARD — must come before colour RAM (see file-level comment). */
    if (addr_in(addr, s->mem_key, GFX_KEY_SIZE))
        return peek_keys(s, addr);

    /* 3. Colour RAM — checked after keyboard to avoid the address alias. */
    if (addr_in(addr, s->mem_color, GFX_COLOR_SIZE))
        return peek_color(s, addr);

    /* 4 + 5. Character RAM and hi-res bitmap. Disambiguate via screen_mode
     *        when an address falls inside the bitmap/chars overlap. */
    in_chars  = addr_in(addr, s->mem_char,   GFX_CHAR_SIZE);
    in_bitmap = addr_in(addr, s->mem_bitmap, GFX_BITMAP_BYTES);
    if (in_chars && in_bitmap) {
        if (s->screen_mode == GFX_SCREEN_BITMAP)
            return peek_bitmap(s, addr);
        return peek_chars(s, addr);
    }
    if (in_chars)  return peek_chars(s, addr);
    if (in_bitmap) return peek_bitmap(s, addr);

    /* Everything else currently undefined: read as 0. */
    return 0;
}

static void poke_text(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - s->mem_text;
    if (offset < GFX_TEXT_SIZE) {
        s->screen[offset] = value;
    }
}

static void poke_color(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - s->mem_color;
    if (offset < GFX_COLOR_SIZE) {
        s->color[offset] = (uint8_t)(value & 0x0Fu); /* palette index 0–15 */
    }
}

static void poke_chars(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - s->mem_char;
    if (offset < GFX_CHAR_SIZE) {
        s->chars[offset] = value;
    }
}

static void poke_bitmap(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - s->mem_bitmap;
    if (offset < GFX_BITMAP_BYTES) {
        s->bitmap[offset] = value;
    }
}

/* gfx_poke — virtualised POKE. See the gfx_peek comment above for the
 * two overlap rules (keyboard-vs-colour, and bitmap-vs-chars under
 * screen_mode). gfx_poke must mirror gfx_peek's dispatch exactly so a
 * write/read round-trip always lands in the same backing store. */
void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    int in_chars, in_bitmap;

    if (!s) return;

    if (addr_in(addr, s->mem_text, GFX_TEXT_SIZE)) {
        poke_text(s, addr, value);
        return;
    }
    /* Keyboard region is read-only via gfx_peek; writes to that range fall
     * through to colour RAM as before (no poke_keys handler). */
    if (addr_in(addr, s->mem_color, GFX_COLOR_SIZE)) {
        poke_color(s, addr, value);
        return;
    }

    in_chars  = addr_in(addr, s->mem_char,   GFX_CHAR_SIZE);
    in_bitmap = addr_in(addr, s->mem_bitmap, GFX_BITMAP_BYTES);
    if (in_chars && in_bitmap) {
        if (s->screen_mode == GFX_SCREEN_BITMAP)
            poke_bitmap(s, addr, value);
        else
            poke_chars(s, addr, value);
        return;
    }
    if (in_chars)  { poke_chars(s, addr, value);  return; }
    if (in_bitmap) { poke_bitmap(s, addr, value); return; }
    /* All other addresses are ignored for now. */
}

int gfx_bitmap_get_pixel(const GfxVideoState *s, unsigned x, unsigned y)
{
    unsigned byte_off, bit;

    if (!s) return 0;
    if (x >= GFX_BITMAP_WIDTH || y >= GFX_BITMAP_HEIGHT) return 0;
    byte_off = y * (GFX_BITMAP_WIDTH / 8u) + (x / 8u);
    if (byte_off >= GFX_BITMAP_BYTES) return 0;
    bit = 7u - (x % 8u);
    return (s->bitmap[byte_off] >> bit) & 1u;
}

void gfx_bitmap_set_pixel(GfxVideoState *s, int x, int y, int on)
{
    unsigned byte_off, bit;
    unsigned ux, uy;
    uint8_t mask;

    if (!s) return;
    if (x < 0 || y < 0) return;
    ux = (unsigned)x;
    uy = (unsigned)y;
    if (ux >= GFX_BITMAP_WIDTH || uy >= GFX_BITMAP_HEIGHT) return;
    byte_off = uy * (GFX_BITMAP_WIDTH / 8u) + (ux / 8u);
    if (byte_off >= GFX_BITMAP_BYTES) return;
    bit = 7u - (ux % 8u);
    mask = (uint8_t)(1u << bit);
    if (on) {
        s->bitmap[byte_off] |= mask;
    } else {
        s->bitmap[byte_off] &= (uint8_t)~mask;
    }
}

void gfx_video_bitmap_clear(GfxVideoState *s)
{
    if (!s) return;
    memset(s->bitmap, 0, sizeof(s->bitmap));
}

/* Character-set-in-bitmap-mode glyph stamper.
 *
 * Each glyph in s->chars[] is 8 bytes, one byte per pixel row, MSB = left
 * pixel (matches the C64 / PET chargen layout). The bitmap is row-major at
 * 40 bytes per row, so cell (col, row) maps to bitmap byte offset
 *   ((row * 8 + glyph_row) * 40) + col
 * i.e. each of the 8 glyph rows lands in a single cell-aligned byte.
 *
 * This is deliberately byte-aligned only — character-set rendering is
 * always on 8-pixel column boundaries. Fonts / DRAWTEXT will need a
 * different (shifted) stamper.
 */
/* Pixel-space glyph stamp — arbitrary (x, y), handling mid-byte x via
 * two-byte shift per row. Transparent background (OR). Used by
 * DRAWTEXT. */
void gfx_video_bitmap_stamp_glyph_px(GfxVideoState *s,
                                     int x, int y,
                                     uint8_t screencode)
{
    const uint8_t *glyph;
    int gr;
    unsigned row_bytes = GFX_BITMAP_WIDTH / 8u;
    if (!s) return;
    glyph = &s->chars[(unsigned)screencode * 8u];
    for (gr = 0; gr < 8; gr++) {
        int py = y + gr;
        int byte_left_x = x >> 3;
        unsigned byte_off;
        int shift;
        uint8_t bits = glyph[gr];
        if (py < 0 || py >= (int)GFX_BITMAP_HEIGHT) continue;
        byte_off = (unsigned)py * row_bytes + (unsigned)byte_left_x;
        shift = x & 7;
        if (byte_left_x >= 0 && (unsigned)byte_left_x < row_bytes) {
            s->bitmap[byte_off] |= (uint8_t)(bits >> shift);
        }
        if (shift != 0 && byte_left_x + 1 >= 0 && (unsigned)(byte_left_x + 1) < row_bytes) {
            s->bitmap[byte_off + 1] |= (uint8_t)(bits << (8 - shift));
        }
    }
}

void gfx_video_bitmap_stamp_glyph(GfxVideoState *s,
                                  int col, int row,
                                  uint8_t screencode,
                                  int solid_bg)
{
    const uint8_t *glyph;
    int glyph_row;

    if (!s) return;
    if (col < 0 || col >= 40) return;
    if (row < 0 || row >= 25) return;

    glyph = &s->chars[(unsigned)screencode * 8u];

    for (glyph_row = 0; glyph_row < 8; glyph_row++) {
        unsigned pixel_y = (unsigned)row * 8u + (unsigned)glyph_row;
        unsigned byte_off = pixel_y * (GFX_BITMAP_WIDTH / 8u) + (unsigned)col;
        uint8_t bits = glyph[glyph_row];
        if (byte_off >= GFX_BITMAP_BYTES) continue;
        if (solid_bg) {
            s->bitmap[byte_off] = bits;
        } else {
            s->bitmap[byte_off] |= bits;
        }
    }
}

/* Scroll the 1bpp bitmap up by one character cell (8 pixel rows).
 *
 * The bitmap is 320x200, row-major, 40 bytes per row. One character
 * cell = 8 pixel rows = 8 * 40 = 320 bytes. The top 320 bytes roll
 * off; the remaining (200 - 8) * 40 = 7680 bytes shift up; the
 * bottom 320 bytes are cleared. memmove is safe for overlapping
 * source/dest. */
void gfx_video_bitmap_scroll_up_cell(GfxVideoState *s)
{
    const size_t row_bytes  = GFX_BITMAP_WIDTH / 8u;   /* 40 */
    const size_t cell_rows  = 8u;
    const size_t cell_bytes = cell_rows * row_bytes;   /* 320 */
    const size_t keep_bytes = GFX_BITMAP_BYTES - cell_bytes; /* 7680 */

    if (!s) return;
    memmove(&s->bitmap[0], &s->bitmap[cell_bytes], keep_bytes);
    memset(&s->bitmap[keep_bytes], 0, cell_bytes);
}

void gfx_bitmap_line(GfxVideoState *s, int x0, int y0, int x1, int y1, int on)
{
    int dx, dy, sx, sy, err, e2;

    if (!s) return;
    dx = abs(x1 - x0);
    dy = -abs(y1 - y0);
    sx = x0 < x1 ? 1 : -1;
    sy = y0 < y1 ? 1 : -1;
    err = dx + dy;
    for (;;) {
        gfx_bitmap_set_pixel(s, x0, y0, on);
        if (x0 == x1 && y0 == y1) {
            break;
        }
        e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

