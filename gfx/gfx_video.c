#include "gfx_video.h"
#include <string.h>

void gfx_video_init(GfxVideoState *s)
{
    if (!s) return;
    memset(s, 0, sizeof(*s));
    s->bg_color = 6; /* default C64 blue background */
    s->charset_lowercase = 0;
    s->key_q_head = 0;
    s->key_q_tail = 0;
    s->ticks60 = 0;
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
    uint16_t offset = addr - GFX_TEXT_BASE;
    if (offset < GFX_TEXT_SIZE) {
        return s->screen[offset];
    }
    return 0;
}

static uint8_t peek_color(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - GFX_COLOR_BASE;
    if (offset < GFX_COLOR_SIZE) {
        return s->color[offset];
    }
    return 0;
}

static uint8_t peek_chars(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - GFX_CHAR_BASE;
    if (offset < GFX_CHAR_SIZE) {
        return s->chars[offset];
    }
    return 0;
}

static uint8_t peek_bitmap(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - GFX_BITMAP_BASE;
    if (offset < GFX_BITMAP_BYTES) {
        return s->bitmap[offset];
    }
    return 0;
}

static uint8_t peek_keys(const GfxVideoState *s, uint16_t addr)
{
    uint16_t offset = addr - GFX_KEY_BASE;
    if (offset < GFX_KEY_SIZE) {
        return s->key_state[offset];
    }
    return 0;
}

uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr)
{
    if (!s) return 0;
    if (addr >= GFX_TEXT_BASE && addr < GFX_TEXT_BASE + GFX_TEXT_SIZE)
        return peek_text(s, addr);
    if (addr >= GFX_COLOR_BASE && addr < GFX_COLOR_BASE + GFX_COLOR_SIZE)
        return peek_color(s, addr);
    if (addr >= GFX_CHAR_BASE && addr < GFX_CHAR_BASE + GFX_CHAR_SIZE)
        return peek_chars(s, addr);
    if (addr >= GFX_KEY_BASE && addr < GFX_KEY_BASE + GFX_KEY_SIZE)
        return peek_keys(s, addr);
    if (addr >= GFX_BITMAP_BASE && addr < GFX_BITMAP_BASE + GFX_BITMAP_BYTES)
        return peek_bitmap(s, addr);
    /* Everything else currently undefined: read as 0. */
    return 0;
}

static void poke_text(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - GFX_TEXT_BASE;
    if (offset < GFX_TEXT_SIZE) {
        s->screen[offset] = value;
    }
}

static void poke_color(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - GFX_COLOR_BASE;
    if (offset < GFX_COLOR_SIZE) {
        s->color[offset] = (uint8_t)(value & 0x0Fu); /* palette index 0–15 */
    }
}

static void poke_chars(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - GFX_CHAR_BASE;
    if (offset < GFX_CHAR_SIZE) {
        s->chars[offset] = value;
    }
}

static void poke_bitmap(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    uint16_t offset = addr - GFX_BITMAP_BASE;
    if (offset < GFX_BITMAP_BYTES) {
        s->bitmap[offset] = value;
    }
}

void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value)
{
    if (!s) return;
    if (addr >= GFX_TEXT_BASE && addr < GFX_TEXT_BASE + GFX_TEXT_SIZE) {
        poke_text(s, addr, value);
        return;
    }
    if (addr >= GFX_COLOR_BASE && addr < GFX_COLOR_BASE + GFX_COLOR_SIZE) {
        poke_color(s, addr, value);
        return;
    }
    if (addr >= GFX_CHAR_BASE && addr < GFX_CHAR_BASE + GFX_CHAR_SIZE) {
        poke_chars(s, addr, value);
        return;
    }
    if (addr >= GFX_BITMAP_BASE && addr < GFX_BITMAP_BASE + GFX_BITMAP_BYTES) {
        poke_bitmap(s, addr, value);
        return;
    }
    /* All other addresses are ignored for now. */
}

