#include <stdio.h>
#include <stdint.h>
#include <assert.h>

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

    /* Out-of-range addresses are inert/zero. */
    gfx_poke(&s, 0x0001u, 0x7F);
    assert(gfx_peek(&s, 0x0001u) == 0);

    printf("gfx_video_test OK\n");
    return 0;
}

