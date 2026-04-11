#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>

#include "gfx_video.h"

int main(void)
{
    GfxVideoState s;
    gfx_video_init(&s);

    /* All memory should start cleared. */
    for (size_t i = 0; i < GFX_TEXT_SIZE; i++) {
        assert(s.screen[i] == 0);
        assert(gfx_peek(&s, GFX_TEXT_BASE + (uint16_t)i) == 0);
    }

    /* Text RAM write/read. */
    gfx_poke(&s, GFX_TEXT_BASE + 0, 65);  /* 'A' */
    gfx_poke(&s, GFX_TEXT_BASE + 39, 66); /* 'B' at end of first row */
    assert(s.screen[0] == 65);
    assert(s.screen[39] == 66);
    assert(gfx_peek(&s, GFX_TEXT_BASE) == 65);
    assert(gfx_peek(&s, GFX_TEXT_BASE + 39) == 66);

    /* Colour RAM clamps to low 4 bits. */
    gfx_poke(&s, GFX_COLOR_BASE, 0x1F);
    assert(s.color[0] == 0x0F);
    assert(gfx_peek(&s, GFX_COLOR_BASE) == 0x0F);

    /* Character ROM/UDG region. */
    gfx_poke(&s, GFX_CHAR_BASE + 7, 0xAA);
    assert(s.chars[7] == 0xAA);
    assert(gfx_peek(&s, GFX_CHAR_BASE + 7) == 0xAA);

    /* Bitmap RAM. */
    gfx_poke(&s, GFX_BITMAP_BASE, 0xFF);
    assert(s.bitmap[0] == 0xFF);
    assert(gfx_peek(&s, GFX_BITMAP_BASE) == 0xFF);

    /* 320×200 layout: row 0 byte 0, MSB = x=0. */
    gfx_poke(&s, GFX_BITMAP_BASE, 0x80);
    assert(gfx_bitmap_get_pixel(&s, 0, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 1, 0) == 0);
    gfx_poke(&s, GFX_BITMAP_BASE, 0x01);
    assert(gfx_bitmap_get_pixel(&s, 7, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 0, 0) == 0);
    /* Second row starts at byte offset 40. */
    gfx_poke(&s, GFX_BITMAP_BASE + 40, 0x80);
    assert(gfx_bitmap_get_pixel(&s, 0, 1) == 1);

    gfx_bitmap_set_pixel(&s, 2, 0, 1);
    assert(gfx_bitmap_get_pixel(&s, 2, 0) == 1);
    gfx_bitmap_set_pixel(&s, 2, 0, 0);
    assert(gfx_bitmap_get_pixel(&s, 2, 0) == 0);
    gfx_poke(&s, GFX_BITMAP_BASE, 0);
    gfx_bitmap_set_pixel(&s, -1, 0, 1);
    gfx_bitmap_set_pixel(&s, 400, 0, 1);
    gfx_bitmap_set_pixel(&s, 0, 300, 1);
    assert(gfx_bitmap_get_pixel(&s, 0, 0) == 0);

    memset(s.bitmap, 0, sizeof(s.bitmap));
    gfx_bitmap_line(&s, 0, 0, 3, 0, 1);
    assert(gfx_bitmap_get_pixel(&s, 0, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 1, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 2, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 3, 0) == 1);
    assert(gfx_bitmap_get_pixel(&s, 4, 0) == 0);

    memset(s.bitmap, 0, sizeof(s.bitmap));
    gfx_bitmap_line(&s, 5, 5, 5, 8, 1);
    assert(gfx_bitmap_get_pixel(&s, 5, 5) == 1);
    assert(gfx_bitmap_get_pixel(&s, 5, 6) == 1);
    assert(gfx_bitmap_get_pixel(&s, 5, 7) == 1);
    assert(gfx_bitmap_get_pixel(&s, 5, 8) == 1);
    assert(gfx_bitmap_get_pixel(&s, 5, 9) == 0);

    assert(s.screen_mode == GFX_SCREEN_TEXT);
    assert(s.scroll_x == 0 && s.scroll_y == 0);
    s.scroll_x = 16;
    s.scroll_y = -8;
    assert(s.scroll_x == 16 && s.scroll_y == -8);

    /* Default layout: GFX_KEY_BASE (0xDC00) lies inside colour RAM window (0xD800..).
     * gfx_peek must resolve keyboard before colour or PEEK(56320+n) reads colour bytes. */
    {
        uint16_t ka = GFX_KEY_BASE + 87;
        uint16_t co = (uint16_t)(ka - GFX_COLOR_BASE);
        assert(co < GFX_COLOR_SIZE);
        s.color[co] = 0x0E;
        s.key_state[87] = 1;
        assert(gfx_peek(&s, ka) == 1); /* not 0x0E from colour RAM */
        s.key_state[87] = 0;
        /* Keyboard range still wins: 0 from key_state, not colour 0x0E (bug was colour first). */
        assert(gfx_peek(&s, ka) == 0);
    }

    /* Out-of-range addresses are inert/zero. */
    gfx_poke(&s, 0x0001u, 0x7F);
    assert(gfx_peek(&s, 0x0001u) == 0);

    /* PET preset: screen at $8000, etc. */
    assert(gfx_video_apply_memory_preset(&s, "pet") == 0);
    gfx_poke(&s, 0x8000u, 77);
    assert(s.screen[0] == 77);
    assert(gfx_peek(&s, 0x8000u) == 77);
    assert(gfx_video_apply_memory_preset(&s, "c64") == 0);
    gfx_poke(&s, GFX_TEXT_BASE, 88);
    assert(s.screen[0] == 88);

    /* Layout that does not fit in 64K is rejected. */
    {
        GfxVideoState t;
        gfx_video_init(&t);
        assert(gfx_video_set_memory_bases(&t, 64000u, GFX_COLOR_BASE, GFX_CHAR_BASE, GFX_KEY_BASE, GFX_BITMAP_BASE) == -1);
    }

    printf("gfx_video_test OK\n");
    return 0;
}

