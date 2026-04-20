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
#include <math.h>

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
    /* Multi-plane table: slots 0 and 1 always reference the inline bitmaps;
     * slots 2..7 are empty until SCREEN BUFFER n allocates them. Defaults
     * match pre-multiplane behaviour (draw and show both target bitmap[]). */
    s->screen_buffers[0] = s->bitmap;
    s->screen_buffers[1] = s->bitmap_show;
    s->screen_draw = 0;
    s->screen_show = 0;
    /* SCREEN 2 pen defaults: opaque white on fully-transparent black.
     * Planes are lazily allocated on first SCREEN 2 entry. */
    s->bitmap_rgba = NULL;
    s->bitmap_rgba_show = NULL;
    s->pen_r = 0xFF; s->pen_g = 0xFF; s->pen_b = 0xFF; s->pen_a = 0xFF;
    s->bgrgba_r = 0; s->bgrgba_g = 0; s->bgrgba_b = 0; s->bgrgba_a = 0xFF;
    /* Populate palette entries 16..255 with the HSV rainbow once per
     * process. Safe to call repeatedly — reset is memcpy + compute. */
    gfx_palette_reset();
}

uint8_t *gfx_video_draw_plane(GfxVideoState *s)
{
    uint8_t *p;
    if (!s) return NULL;
    p = s->screen_buffers[s->screen_draw & (GFX_MAX_SCREEN_BUFFERS - 1u)];
    return p ? p : s->bitmap;
}

const uint8_t *gfx_video_show_plane(const GfxVideoState *s)
{
    const uint8_t *p;
    if (!s) return NULL;
    p = s->screen_buffers[s->screen_show & (GFX_MAX_SCREEN_BUFFERS - 1u)];
    return p ? p : s->bitmap;
}

int gfx_video_screen_buffer_alloc(GfxVideoState *s, int slot)
{
    if (!s) return -1;
    if (slot < 2 || slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (s->screen_buffers[slot]) return 0;             /* already live */
    s->screen_buffers[slot] = (uint8_t *)calloc(GFX_BITMAP_BYTES, 1u);
    if (!s->screen_buffers[slot]) return -1;
    s->screen_buffer_owned[slot] = 1u;
    return 0;
}

int gfx_video_screen_buffer_free(GfxVideoState *s, int slot)
{
    if (!s) return -1;
    if (slot < 2 || slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if ((int)s->screen_draw == slot || (int)s->screen_show == slot) return -1;
    if (s->screen_buffer_owned[slot] && s->screen_buffers[slot]) {
        free(s->screen_buffers[slot]);
    }
    s->screen_buffers[slot] = NULL;
    s->screen_buffer_owned[slot] = 0u;
    return 0;
}

int gfx_video_screen_set_draw(GfxVideoState *s, int slot)
{
    if (!s) return -1;
    if (slot < 0 || slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (!s->screen_buffers[slot]) return -1;
    s->screen_draw = (uint8_t)slot;
    return 0;
}

int gfx_video_screen_set_show(GfxVideoState *s, int slot)
{
    if (!s) return -1;
    if (slot < 0 || slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (!s->screen_buffers[slot]) return -1;
    s->screen_show = (uint8_t)slot;
    return 0;
}

int gfx_video_screen_swap(GfxVideoState *s, int draw_slot, int show_slot)
{
    if (!s) return -1;
    if (draw_slot < 0 || draw_slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (show_slot < 0 || show_slot >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (!s->screen_buffers[draw_slot] || !s->screen_buffers[show_slot]) return -1;
    s->screen_draw = (uint8_t)draw_slot;
    s->screen_show = (uint8_t)show_slot;
    return 0;
}

int gfx_video_screen_copy(GfxVideoState *s, int src, int dst)
{
    if (!s) return -1;
    if (src < 0 || src >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (dst < 0 || dst >= (int)GFX_MAX_SCREEN_BUFFERS) return -1;
    if (!s->screen_buffers[src] || !s->screen_buffers[dst]) return -1;
    if (src == dst) return 0;
    memcpy(s->screen_buffers[dst], s->screen_buffers[src], GFX_BITMAP_BYTES);
    return 0;
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
        const uint8_t *plane = s->screen_buffers[s->screen_draw];
        return (plane ? plane : s->bitmap)[offset];
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
        uint8_t *plane = s->screen_buffers[s->screen_draw];
        (plane ? plane : s->bitmap)[offset] = value;
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
    const uint8_t *plane;

    if (!s) return 0;
    if (x >= GFX_BITMAP_WIDTH || y >= GFX_BITMAP_HEIGHT) return 0;
    byte_off = y * (GFX_BITMAP_WIDTH / 8u) + (x / 8u);
    if (byte_off >= GFX_BITMAP_BYTES) return 0;
    bit = 7u - (x % 8u);
    plane = s->screen_buffers[s->screen_draw];
    if (!plane) plane = s->bitmap;
    return (plane[byte_off] >> bit) & 1u;
}

int gfx_bitmap_get_show_pixel(const GfxVideoState *s, unsigned x, unsigned y)
{
    unsigned byte_off, bit;
    const uint8_t *src;

    if (!s) return 0;
    if (x >= GFX_BITMAP_WIDTH || y >= GFX_BITMAP_HEIGHT) return 0;
    byte_off = y * (GFX_BITMAP_WIDTH / 8u) + (x / 8u);
    if (byte_off >= GFX_BITMAP_BYTES) return 0;
    bit = 7u - (x % 8u);
    src = gfx_video_show_plane(s);
    if (!src) src = s->bitmap;
    return (src[byte_off] >> bit) & 1u;
}

int gfx_bitmap_get_show_color(const GfxVideoState *s, unsigned x, unsigned y)
{
    const uint8_t *src;
    if (!s) return 0;
    if (x >= GFX_BITMAP_WIDTH || y >= GFX_BITMAP_HEIGHT) return 0;
    /* Double-buffer ON with show==slot 1: sample the flipped colour
     * plane so pixels stay in the colour they were committed with. All
     * other configurations read the live colour plane (only the main
     * bitmap — slot 0 — has one). */
    src = (s->double_buffer && s->screen_show == 1) ? s->bitmap_color_show : s->bitmap_color;
    return src[y * GFX_BITMAP_WIDTH + x] & 0x0Fu;
}

/* 256-entry writable palette. Entries 0..15 = C64 defaults (SCREEN 1
 * and SCREEN 2 COLOR n indices). Entries 16..255 default to a 240-step
 * HSV rainbow so SCREEN 3 has usable colours out of the box — programs
 * can overwrite any entry with PALETTESET. */
uint8_t gfx_c64_palette_rgb[256][4] = {
    { 0x00, 0x00, 0x00, 0xFF }, { 0xFF, 0xFF, 0xFF, 0xFF },
    { 0x88, 0x00, 0x00, 0xFF }, { 0xAA, 0xFF, 0xEE, 0xFF },
    { 0xCC, 0x44, 0xCC, 0xFF }, { 0x00, 0xCC, 0x55, 0xFF },
    { 0x00, 0x00, 0xAA, 0xFF }, { 0xEE, 0xEE, 0x77, 0xFF },
    { 0xDD, 0x88, 0x55, 0xFF }, { 0x66, 0x44, 0x00, 0xFF },
    { 0xFF, 0x77, 0x77, 0xFF }, { 0x33, 0x33, 0x33, 0xFF },
    { 0x77, 0x77, 0x77, 0xFF }, { 0xAA, 0xFF, 0x66, 0xFF },
    { 0x00, 0x88, 0xFF, 0xFF }, { 0xBB, 0xBB, 0xBB, 0xFF },
    /* 16..255 filled in by gfx_palette_reset on first init. */
};

static const uint8_t gfx_palette_c64_defaults[16][4] = {
    { 0x00, 0x00, 0x00, 0xFF }, { 0xFF, 0xFF, 0xFF, 0xFF },
    { 0x88, 0x00, 0x00, 0xFF }, { 0xAA, 0xFF, 0xEE, 0xFF },
    { 0xCC, 0x44, 0xCC, 0xFF }, { 0x00, 0xCC, 0x55, 0xFF },
    { 0x00, 0x00, 0xAA, 0xFF }, { 0xEE, 0xEE, 0x77, 0xFF },
    { 0xDD, 0x88, 0x55, 0xFF }, { 0x66, 0x44, 0x00, 0xFF },
    { 0xFF, 0x77, 0x77, 0xFF }, { 0x33, 0x33, 0x33, 0xFF },
    { 0x77, 0x77, 0x77, 0xFF }, { 0xAA, 0xFF, 0x66, 0xFF },
    { 0x00, 0x88, 0xFF, 0xFF }, { 0xBB, 0xBB, 0xBB, 0xFF },
};

/* HSV -> RGB for palette reset. h in [0, 360), s and v in [0, 1]. */
static void hsv_to_rgb(double h, double s, double v, uint8_t *r, uint8_t *g, uint8_t *b)
{
    double c = v * s;
    double hh = h / 60.0;
    double x = c * (1.0 - fabs(fmod(hh, 2.0) - 1.0));
    double m = v - c;
    double r1 = 0, g1 = 0, b1 = 0;
    if      (hh < 1) { r1 = c; g1 = x; b1 = 0; }
    else if (hh < 2) { r1 = x; g1 = c; b1 = 0; }
    else if (hh < 3) { r1 = 0; g1 = c; b1 = x; }
    else if (hh < 4) { r1 = 0; g1 = x; b1 = c; }
    else if (hh < 5) { r1 = x; g1 = 0; b1 = c; }
    else             { r1 = c; g1 = 0; b1 = x; }
    *r = (uint8_t)((r1 + m) * 255.0 + 0.5);
    *g = (uint8_t)((g1 + m) * 255.0 + 0.5);
    *b = (uint8_t)((b1 + m) * 255.0 + 0.5);
}

void gfx_palette_reset(void)
{
    int i;
    memcpy(gfx_c64_palette_rgb, gfx_palette_c64_defaults, sizeof(gfx_palette_c64_defaults));
    /* 240 HSV rainbow entries for SCREEN 3. Stripe by saturation /
     * value bands so similar indices look different (useful for index-
     * as-debug-tag). */
    for (i = 16; i < 256; i++) {
        int j = i - 16;                      /* 0..239 */
        int band = j / 40;                   /* 0..5 saturation/value band */
        int slot = j % 40;                   /* 0..39 hue slot */
        double h = (double)slot * 9.0;       /* 0..351 deg */
        double s = 1.0;
        double v = 1.0;
        switch (band) {
            case 0: v = 1.0; s = 1.0; break;   /* pure bright */
            case 1: v = 0.75; s = 1.0; break;  /* mid */
            case 2: v = 0.5; s = 1.0; break;   /* dark */
            case 3: v = 1.0; s = 0.5; break;   /* pastel */
            case 4: v = 0.75; s = 0.5; break;  /* muted */
            case 5:
                /* Last band: greyscale ramp so programs always have a
                 * usable black-to-white axis at the top of the palette. */
                v = (double)slot / 39.0;
                s = 0.0;
                break;
        }
        hsv_to_rgb(h, s, v, &gfx_c64_palette_rgb[i][0],
                              &gfx_c64_palette_rgb[i][1],
                              &gfx_c64_palette_rgb[i][2]);
        gfx_c64_palette_rgb[i][3] = 0xFF;
    }
}

/* ── SCREEN 2 RGBA plane ─────────────────────────────────────────── */

int gfx_rgba_alloc(GfxVideoState *s)
{
    if (!s) return -1;
    if (s->bitmap_rgba && s->bitmap_rgba_show) return 0;
    if (!s->bitmap_rgba) {
        s->bitmap_rgba = (uint8_t *)calloc(GFX_RGBA_BYTES, 1u);
        if (!s->bitmap_rgba) return -1;
    }
    if (!s->bitmap_rgba_show) {
        s->bitmap_rgba_show = (uint8_t *)calloc(GFX_RGBA_BYTES, 1u);
        if (!s->bitmap_rgba_show) return -1;
    }
    return 0;
}

void gfx_rgba_clear(GfxVideoState *s)
{
    uint8_t *p;
    size_t i;
    if (!s || !s->bitmap_rgba) return;
    p = s->bitmap_rgba;
    for (i = 0; i < GFX_RGBA_BYTES; i += 4u) {
        p[i + 0] = s->bgrgba_r;
        p[i + 1] = s->bgrgba_g;
        p[i + 2] = s->bgrgba_b;
        p[i + 3] = s->bgrgba_a;
    }
}

void gfx_rgba_set_pixel(GfxVideoState *s, int x, int y)
{
    unsigned off;
    if (!s || !s->bitmap_rgba) return;
    if (x < 0 || y < 0) return;
    if ((unsigned)x >= GFX_BITMAP_WIDTH || (unsigned)y >= GFX_BITMAP_HEIGHT) return;
    off = ((unsigned)y * GFX_BITMAP_WIDTH + (unsigned)x) * 4u;
    s->bitmap_rgba[off + 0] = s->pen_r;
    s->bitmap_rgba[off + 1] = s->pen_g;
    s->bitmap_rgba[off + 2] = s->pen_b;
    s->bitmap_rgba[off + 3] = s->pen_a;
}

void gfx_rgba_line(GfxVideoState *s, int x0, int y0, int x1, int y1)
{
    int dx, dy, sx, sy, err, e2;
    if (!s || !s->bitmap_rgba) return;
    dx = abs(x1 - x0);
    dy = -abs(y1 - y0);
    sx = x0 < x1 ? 1 : -1;
    sy = y0 < y1 ? 1 : -1;
    err = dx + dy;
    for (;;) {
        gfx_rgba_set_pixel(s, x0, y0);
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

void gfx_rgba_fill_rect(GfxVideoState *s, int x0, int y0, int x1, int y1)
{
    int y;
    if (x0 > x1) { int t = x0; x0 = x1; x1 = t; }
    if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
    for (y = y0; y <= y1; y++) gfx_rgba_line(s, x0, y, x1, y);
}

int gfx_rgba_get_show_pixel(const GfxVideoState *s, unsigned x, unsigned y, uint8_t out[4])
{
    const uint8_t *src;
    unsigned off;
    if (!s || !out) return 0;
    if (x >= GFX_BITMAP_WIDTH || y >= GFX_BITMAP_HEIGHT) return 0;
    src = (s->double_buffer && s->bitmap_rgba_show) ? s->bitmap_rgba_show : s->bitmap_rgba;
    if (!src) return 0;
    off = (y * GFX_BITMAP_WIDTH + x) * 4u;
    out[0] = src[off + 0];
    out[1] = src[off + 1];
    out[2] = src[off + 2];
    out[3] = src[off + 3];
    return 1;
}

void gfx_rgba_flip(GfxVideoState *s)
{
    if (!s) return;
    if (!s->bitmap_rgba || !s->bitmap_rgba_show) return;
    memcpy(s->bitmap_rgba_show, s->bitmap_rgba, GFX_RGBA_BYTES);
}

void gfx_rgba_stamp_glyph_px(GfxVideoState *s, int x, int y, uint8_t screencode)
{
    const uint8_t *glyph;
    int gr, gc;
    if (!s || !s->bitmap_rgba) return;
    glyph = &s->chars[(unsigned)screencode * 8u];
    for (gr = 0; gr < 8; gr++) {
        uint8_t bits = glyph[gr];
        int py = y + gr;
        if (py < 0 || py >= (int)GFX_BITMAP_HEIGHT) continue;
        for (gc = 0; gc < 8; gc++) {
            if ((bits >> (7 - gc)) & 1u) {
                gfx_rgba_set_pixel(s, x + gc, py);
            }
        }
    }
}

void gfx_rgba_stamp_glyph_px_scaled(GfxVideoState *s, int x, int y,
                                    uint8_t screencode, int scale)
{
    const uint8_t *glyph;
    int gr, gc, dx, dy;
    if (!s || !s->bitmap_rgba) return;
    if (scale <= 1) { gfx_rgba_stamp_glyph_px(s, x, y, screencode); return; }
    if (scale > 8) scale = 8;
    glyph = &s->chars[(unsigned)screencode * 8u];
    for (gr = 0; gr < 8; gr++) {
        uint8_t bits = glyph[gr];
        for (gc = 0; gc < 8; gc++) {
            if ((bits >> (7 - gc)) & 1u) {
                int px0 = x + gc * scale;
                int py0 = y + gr * scale;
                for (dy = 0; dy < scale; dy++) {
                    for (dx = 0; dx < scale; dx++) {
                        gfx_rgba_set_pixel(s, px0 + dx, py0 + dy);
                    }
                }
            }
        }
    }
}

void gfx_video_bitmap_flip(GfxVideoState *s)
{
    uint8_t *draw, *show;
    if (!s) return;
    if (!s->double_buffer) return;
    /* SCREEN 2: RGBA plane gets its own atomic flip regardless of the
     * 1bpp slot indices (which aren't meaningful in RGBA mode). */
    if (s->screen_mode == GFX_SCREEN_RGBA) { gfx_rgba_flip(s); return; }
    /* SCREEN 3: only the colour plane matters. */
    if (s->screen_mode == GFX_SCREEN_INDEXED) {
        memcpy(s->bitmap_color_show, s->bitmap_color, sizeof(s->bitmap_color));
        return;
    }
    if (s->screen_draw == s->screen_show) return;
    draw = s->screen_buffers[s->screen_draw];
    show = s->screen_buffers[s->screen_show];
    if (!draw || !show) return;
    memcpy(show, draw, GFX_BITMAP_BYTES);
    /* Keep the colour plane in lock-step with the bitmap flip so
     * double-buffered per-pixel colour also commits atomically. */
    if (s->screen_draw == 0 && s->screen_show == 1) {
        memcpy(s->bitmap_color_show, s->bitmap_color, sizeof(s->bitmap_color));
    }
}

void gfx_bitmap_set_pixel(GfxVideoState *s, int x, int y, int on)
{
    unsigned byte_off, bit;
    unsigned ux, uy;
    uint8_t mask;
    uint8_t *plane;

    if (!s) return;
    /* SCREEN 2 dispatch — 1bpp bit/plane ignored; write RGBA using the
     * current RGBA pen (or the background colour for `on == 0`). Caller
     * transparency is achieved by picking pen_a == 0, not by skipping
     * the write, so overwrite semantics match the 1bpp path. */
    if (s->screen_mode == GFX_SCREEN_RGBA) {
        if (on) {
            gfx_rgba_set_pixel(s, x, y);
        } else {
            uint8_t pr = s->pen_r, pg = s->pen_g, pb = s->pen_b, pa = s->pen_a;
            s->pen_r = s->bgrgba_r; s->pen_g = s->bgrgba_g;
            s->pen_b = s->bgrgba_b; s->pen_a = s->bgrgba_a;
            gfx_rgba_set_pixel(s, x, y);
            s->pen_r = pr; s->pen_g = pg; s->pen_b = pb; s->pen_a = pa;
        }
        return;
    }
    /* SCREEN 3 dispatch — bitmap_color[] stores the full 8-bit palette
     * index for each pixel. Writes go directly there; bitmap[] bit
     * plane is unused in this mode. `on == 0` paints bg_color. */
    if (s->screen_mode == GFX_SCREEN_INDEXED) {
        if (x < 0 || y < 0) return;
        if ((unsigned)x >= GFX_BITMAP_WIDTH || (unsigned)y >= GFX_BITMAP_HEIGHT) return;
        s->bitmap_color[(unsigned)y * GFX_BITMAP_WIDTH + (unsigned)x] =
            on ? s->bitmap_fg : s->bg_color;
        return;
    }
    if (x < 0 || y < 0) return;
    ux = (unsigned)x;
    uy = (unsigned)y;
    if (ux >= GFX_BITMAP_WIDTH || uy >= GFX_BITMAP_HEIGHT) return;
    byte_off = uy * (GFX_BITMAP_WIDTH / 8u) + (ux / 8u);
    if (byte_off >= GFX_BITMAP_BYTES) return;
    bit = 7u - (ux % 8u);
    mask = (uint8_t)(1u << bit);
    plane = gfx_video_draw_plane(s);
    if (!plane) return;
    if (on) {
        plane[byte_off] |= mask;
        /* Stamp the current pen index into the colour plane so the
         * renderer can draw each lit pixel in the colour it was set,
         * instead of re-tinting the whole plane with the live
         * `bitmap_fg`. Only stamp on slot 0 (the main bitmap) — other
         * SCREEN BUFFER slots remain 1bpp + single-pen for now. */
        if (s->screen_draw == 0) {
            s->bitmap_color[uy * GFX_BITMAP_WIDTH + ux] = (uint8_t)(s->screen_mode == GFX_SCREEN_INDEXED ? s->bitmap_fg : (s->bitmap_fg & 0x0Fu));
        }
    } else {
        plane[byte_off] &= (uint8_t)~mask;
    }
}

void gfx_video_bitmap_clear(GfxVideoState *s)
{
    uint8_t *plane;
    if (!s) return;
    if (s->screen_mode == GFX_SCREEN_RGBA) { gfx_rgba_clear(s); return; }
    if (s->screen_mode == GFX_SCREEN_INDEXED) {
        /* SCREEN 3 CLS = paint the whole indexed plane with the
         * current bg_color palette index. No bit plane to clear. */
        memset(s->bitmap_color, s->bg_color, sizeof(s->bitmap_color));
        return;
    }
    plane = gfx_video_draw_plane(s);
    if (!plane) return;
    memset(plane, 0, GFX_BITMAP_BYTES);
    /* Only the main bitmap has a companion colour plane. */
    if (s->screen_draw == 0) {
        memset(s->bitmap_color, 0, sizeof(s->bitmap_color));
    }
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
    uint8_t *plane;
    int gr, gc;
    uint8_t pen;
    unsigned row_bytes = GFX_BITMAP_WIDTH / 8u;
    if (!s) return;
    plane = gfx_video_draw_plane(s);
    if (!plane) return;
    pen = (uint8_t)(s->screen_mode == GFX_SCREEN_INDEXED ? s->bitmap_fg : (s->bitmap_fg & 0x0Fu));
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
            plane[byte_off] |= (uint8_t)(bits >> shift);
        }
        if (shift != 0 && byte_left_x + 1 >= 0 && (unsigned)(byte_left_x + 1) < row_bytes) {
            plane[byte_off + 1] |= (uint8_t)(bits << (8 - shift));
        }
        /* Stamp the current pen into the colour plane for every set
         * glyph bit so per-stamp COLOR sticks (only on main slot — the
         * only plane with a colour companion). */
        if (s->screen_draw == 0 && bits) {
            for (gc = 0; gc < 8; gc++) {
                if ((bits >> (7 - gc)) & 1u) {
                    int px = x + gc;
                    if (px >= 0 && px < (int)GFX_BITMAP_WIDTH) {
                        s->bitmap_color[(unsigned)py * GFX_BITMAP_WIDTH + (unsigned)px] = pen;
                    }
                }
            }
        }
    }
}

void gfx_video_bitmap_stamp_glyph_px_scaled(GfxVideoState *s,
                                            int x, int y,
                                            uint8_t screencode,
                                            int scale)
{
    const uint8_t *glyph;
    int gr, gc;
    if (!s) return;
    if (scale <= 1) { gfx_video_bitmap_stamp_glyph_px(s, x, y, screencode); return; }
    if (scale > 8) scale = 8;
    if (!gfx_video_draw_plane(s)) return;
    glyph = &s->chars[(unsigned)screencode * 8u];
    /* Per-source-pixel expansion: walk the 8x8 source, and for each set bit
     * fill a scale×scale block via gfx_bitmap_set_pixel. Uses the current
     * draw plane because set_pixel routes through it. */
    for (gr = 0; gr < 8; gr++) {
        uint8_t bits = glyph[gr];
        for (gc = 0; gc < 8; gc++) {
            if ((bits >> (7 - gc)) & 1u) {
                int px0 = x + gc * scale;
                int py0 = y + gr * scale;
                int dx, dy;
                for (dy = 0; dy < scale; dy++) {
                    for (dx = 0; dx < scale; dx++) {
                        gfx_bitmap_set_pixel(s, px0 + dx, py0 + dy, 1);
                    }
                }
            }
        }
    }
}

void gfx_video_bitmap_stamp_glyph(GfxVideoState *s,
                                  int col, int row,
                                  uint8_t screencode,
                                  int solid_bg)
{
    const uint8_t *glyph;
    uint8_t *plane;
    int glyph_row, gc;
    uint8_t pen;

    if (!s) return;
    if (col < 0 || col >= 40) return;
    if (row < 0 || row >= 25) return;

    plane = gfx_video_draw_plane(s);
    if (!plane) return;
    pen = (uint8_t)(s->screen_mode == GFX_SCREEN_INDEXED ? s->bitmap_fg : (s->bitmap_fg & 0x0Fu));
    glyph = &s->chars[(unsigned)screencode * 8u];

    for (glyph_row = 0; glyph_row < 8; glyph_row++) {
        unsigned pixel_y = (unsigned)row * 8u + (unsigned)glyph_row;
        unsigned byte_off = pixel_y * (GFX_BITMAP_WIDTH / 8u) + (unsigned)col;
        uint8_t bits = glyph[glyph_row];
        if (byte_off >= GFX_BITMAP_BYTES) continue;
        if (solid_bg) {
            plane[byte_off] = bits;
        } else {
            plane[byte_off] |= bits;
        }
        if (s->screen_draw == 0 && bits) {
            int base_x = col * 8;
            for (gc = 0; gc < 8; gc++) {
                if ((bits >> (7 - gc)) & 1u) {
                    s->bitmap_color[pixel_y * GFX_BITMAP_WIDTH + (unsigned)(base_x + gc)] = pen;
                }
            }
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
    uint8_t *plane;

    if (!s) return;
    plane = gfx_video_draw_plane(s);
    if (!plane) return;
    memmove(&plane[0], &plane[cell_bytes], keep_bytes);
    memset(&plane[keep_bytes], 0, cell_bytes);
    /* Scroll the per-pixel colour plane alongside so text colour rolls
     * with the glyphs (main slot only). */
    if (s->screen_draw == 0) {
        const size_t color_cell  = cell_rows * GFX_BITMAP_WIDTH;   /* 8 * 320 */
        const size_t color_total = GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT;
        const size_t color_keep  = color_total - color_cell;
        memmove(&s->bitmap_color[0], &s->bitmap_color[color_cell], color_keep);
        memset(&s->bitmap_color[color_keep], 0, color_cell);
    }
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

