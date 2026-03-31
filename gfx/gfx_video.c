#include "gfx_video.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* Regions may overlap in 16-bit address space (like real machines); gfx_peek/poke use a
 * fixed priority: text, color, char, key, bitmap. Only require each window to fit in 64K. */
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
    s->bitmap_fg = 14; /* default light blue pen (matches text COLOR default) */
    s->charset_lowercase = 0;
    s->cols = 40;    /* 40 or 80; set by basic_set_video from -columns */
    s->key_q_head = 0;
    s->key_q_tail = 0;
    s->ticks60 = 0;
    s->screen_mode = GFX_SCREEN_TEXT;
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

uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr)
{
    if (!s) return 0;
    if (addr >= s->mem_text && addr < s->mem_text + GFX_TEXT_SIZE)
        return peek_text(s, addr);
    if (addr >= s->mem_color && addr < s->mem_color + GFX_COLOR_SIZE)
        return peek_color(s, addr);
    if (addr >= s->mem_char && addr < s->mem_char + GFX_CHAR_SIZE)
        return peek_chars(s, addr);
    if (addr >= s->mem_key && addr < s->mem_key + GFX_KEY_SIZE)
        return peek_keys(s, addr);
    if (addr >= s->mem_bitmap && addr < s->mem_bitmap + GFX_BITMAP_BYTES)
        return peek_bitmap(s, addr);
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

void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    if (!s) return;
    if (addr >= s->mem_text && addr < s->mem_text + GFX_TEXT_SIZE) {
        poke_text(s, addr, value);
        return;
    }
    if (addr >= s->mem_color && addr < s->mem_color + GFX_COLOR_SIZE) {
        poke_color(s, addr, value);
        return;
    }
    if (addr >= s->mem_char && addr < s->mem_char + GFX_CHAR_SIZE) {
        poke_chars(s, addr, value);
        return;
    }
    if (addr >= s->mem_bitmap && addr < s->mem_bitmap + GFX_BITMAP_BYTES) {
        poke_bitmap(s, addr, value);
        return;
    }
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

