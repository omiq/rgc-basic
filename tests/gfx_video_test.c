#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>

#include "gfx_video.h"
#include "gfx_charrom.h"

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

    /* C64 vs PET-style .64c font: same screen-code layout, different glyph bytes. */
    {
        GfxVideoState c64, pet;
        gfx_video_init(&c64);
        c64.charrom_family = 0;
        c64.charset_lowercase = 0;
        gfx_load_default_charrom(&c64);
        gfx_video_init(&pet);
        pet.charrom_family = 1;
        pet.charset_lowercase = 0;
        gfx_load_default_charrom(&pet);
        assert(c64.chars[0] != pet.chars[0]);
    }

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

    /* C64-style memory multiplexing: in the default layout, the bitmap region
     * ($2000-$3F3F, 8000 bytes) overlaps the character RAM region ($3000-$37FF,
     * 2048 bytes). On real hardware, VIC-II uses the same RAM either as bitmap
     * pixels or as character glyphs depending on screen mode — the mode chooses
     * the interpretation, not the address. gfx_poke / gfx_peek must mirror that
     * by consulting screen_mode for any address inside the overlap. */
    {
        GfxVideoState m;
        unsigned x, y;
        unsigned overlap_lo, overlap_hi;
        uint16_t addr;

        gfx_video_init(&m);
        overlap_lo = (unsigned)GFX_CHAR_BASE;                 /* $3000 */
        overlap_hi = (unsigned)GFX_CHAR_BASE + GFX_CHAR_SIZE; /* $3800 */

        /* TEXT mode (default after init): chars region wins for the overlap.
         * This is the existing behaviour and must not regress. */
        assert(m.screen_mode == GFX_SCREEN_TEXT);
        gfx_poke(&m, (uint16_t)overlap_lo, 0xAB);
        assert(m.chars[0] == 0xAB);
        assert(m.bitmap[overlap_lo - GFX_BITMAP_BASE] == 0);
        assert(gfx_peek(&m, (uint16_t)overlap_lo) == 0xAB);

        /* BITMAP mode: same address must now land in the bitmap, not chars.
         * Wipe both planes first so we can attribute writes unambiguously. */
        memset(m.chars, 0, sizeof(m.chars));
        memset(m.bitmap, 0, sizeof(m.bitmap));
        m.screen_mode = GFX_SCREEN_BITMAP;
        gfx_poke(&m, (uint16_t)overlap_lo, 0xCD);
        assert(m.bitmap[overlap_lo - GFX_BITMAP_BASE] == 0xCD);
        assert(m.chars[0] == 0);
        assert(gfx_peek(&m, (uint16_t)overlap_lo) == 0xCD);

        /* BITMAP mode, full-range coverage: clearing the entire 8000-byte
         * bitmap via POKE (i.e. what BASIC's MEMSET does) must wipe every
         * pixel, including those whose backing bytes fall inside the
         * overlap window. With the current bug, bytes $3000-$37FF land
         * in chars instead of bitmap, leaving roughly rows 102-167
         * undisturbed. */
        for (x = 0; x < GFX_BITMAP_WIDTH; x++) {
            gfx_bitmap_set_pixel(&m, (int)x, 0, 1);
            gfx_bitmap_set_pixel(&m, (int)x, GFX_BITMAP_HEIGHT - 1, 1);
        }
        for (y = 0; y < GFX_BITMAP_HEIGHT; y++) {
            gfx_bitmap_set_pixel(&m, 0, (int)y, 1);
            gfx_bitmap_set_pixel(&m, GFX_BITMAP_WIDTH - 1, (int)y, 1);
        }
        /* Pollute the entire 8000-byte bitmap range so we know the clear works. */
        for (addr = GFX_BITMAP_BASE; addr < GFX_BITMAP_BASE + GFX_BITMAP_BYTES; addr++) {
            gfx_poke(&m, addr, 0xFF);
        }
        for (x = 0; x < GFX_BITMAP_WIDTH; x++) {
            for (y = 0; y < GFX_BITMAP_HEIGHT; y++) {
                assert(gfx_bitmap_get_pixel(&m, x, y) == 1);
            }
        }
        /* Now zero the bitmap byte-by-byte and confirm every pixel is off. */
        for (addr = GFX_BITMAP_BASE; addr < GFX_BITMAP_BASE + GFX_BITMAP_BYTES; addr++) {
            gfx_poke(&m, addr, 0x00);
        }
        for (x = 0; x < GFX_BITMAP_WIDTH; x++) {
            for (y = 0; y < GFX_BITMAP_HEIGHT; y++) {
                assert(gfx_bitmap_get_pixel(&m, x, y) == 0);
            }
        }

        /* Returning to TEXT mode restores chars-wins priority. */
        m.screen_mode = GFX_SCREEN_TEXT;
        memset(m.chars, 0, sizeof(m.chars));
        gfx_poke(&m, (uint16_t)(overlap_lo + 1), 0x42);
        assert(m.chars[1] == 0x42);
        assert(gfx_peek(&m, (uint16_t)(overlap_lo + 1)) == 0x42);
        (void)overlap_hi; /* upper bound is informational */
    }

    /* ============================================================
     * Text-in-bitmap-mode step 1: gfx_video_bitmap_clear and
     * gfx_video_bitmap_stamp_glyph. See docs/bitmap-text-plan.md.
     * ============================================================ */
    {
        GfxVideoState b;
        unsigned pixel_y;

        gfx_video_init(&b);
        b.screen_mode = GFX_SCREEN_BITMAP;

        /* Pollute the bitmap, then clear it. */
        memset(b.bitmap, 0xFF, sizeof(b.bitmap));
        gfx_video_bitmap_clear(&b);
        for (size_t i = 0; i < sizeof(b.bitmap); i++) {
            assert(b.bitmap[i] == 0);
        }

        /* The text plane is NOT touched by bitmap clear. */
        memset(b.screen, 'X', sizeof(b.screen));
        gfx_video_bitmap_clear(&b);
        assert(b.screen[0] == 'X');
        assert(b.screen[500] == 'X');

        /* Stamp a known glyph at cell (0, 0) with transparent bg.
         * We put a recognisable pattern in s->chars[screencode * 8]
         * and check it lands at bitmap[0..7 * 40 by stride 40]. */
        {
            uint8_t code = 42;
            uint8_t pattern[8] = {0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81};
            memset(b.bitmap, 0, sizeof(b.bitmap));
            memcpy(&b.chars[(unsigned)code * 8u], pattern, 8);
            gfx_video_bitmap_stamp_glyph(&b, 0, 0, code, 0);
            for (pixel_y = 0; pixel_y < 8; pixel_y++) {
                unsigned off = pixel_y * (GFX_BITMAP_WIDTH / 8u);
                assert(b.bitmap[off] == pattern[pixel_y]);
            }
            /* Cell to the right untouched. */
            assert(b.bitmap[1] == 0);
        }

        /* Stamp at cell (5, 3) — byte offset = (3*8 + gr) * 40 + 5. */
        {
            uint8_t code = 7;
            uint8_t pattern[8] = {0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55};
            memset(b.bitmap, 0, sizeof(b.bitmap));
            memcpy(&b.chars[(unsigned)code * 8u], pattern, 8);
            gfx_video_bitmap_stamp_glyph(&b, 5, 3, code, 0);
            for (pixel_y = 0; pixel_y < 8; pixel_y++) {
                unsigned off = ((unsigned)3 * 8u + pixel_y) * 40u + 5u;
                assert(b.bitmap[off] == pattern[pixel_y]);
            }
        }

        /* Transparent OR vs solid overwrite. */
        {
            uint8_t code = 9;
            uint8_t pattern[8] = {0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F};
            memset(b.bitmap, 0xF0, sizeof(b.bitmap));
            memcpy(&b.chars[(unsigned)code * 8u], pattern, 8);

            /* Transparent: cell byte becomes 0xF0 | 0x0F == 0xFF. */
            gfx_video_bitmap_stamp_glyph(&b, 0, 0, code, 0);
            assert(b.bitmap[0] == 0xFF);

            /* Solid: cell byte becomes 0x0F (paper cleared first). */
            memset(b.bitmap, 0xF0, sizeof(b.bitmap));
            gfx_video_bitmap_stamp_glyph(&b, 0, 0, code, 1);
            assert(b.bitmap[0] == 0x0F);
        }

        /* Out-of-range cells are silently clipped (no crash, no writes). */
        memset(b.bitmap, 0, sizeof(b.bitmap));
        gfx_video_bitmap_stamp_glyph(&b, -1, 0, 42, 1);
        gfx_video_bitmap_stamp_glyph(&b, 40, 0, 42, 1);
        gfx_video_bitmap_stamp_glyph(&b, 0, -1, 42, 1);
        gfx_video_bitmap_stamp_glyph(&b, 0, 25, 42, 1);
        for (size_t i = 0; i < sizeof(b.bitmap); i++) {
            assert(b.bitmap[i] == 0);
        }

        /* NULL state is tolerated. */
        gfx_video_bitmap_clear(NULL);
        gfx_video_bitmap_stamp_glyph(NULL, 0, 0, 0, 0);
    }

    /* ============================================================
     * Step 2 integration sketch: walk a string the way gfx_put_byte
     * does in bitmap mode (solid-bg stamp at each cell, advance col,
     * wrap row, clip at row 25). Uses the real loaded chargen so
     * the glyph bytes exercised match what a live PRINT would emit.
     * ============================================================ */
    {
        GfxVideoState b;
        const char *msg = "HI";
        int col = 0, row = 0;

        gfx_video_init(&b);
        b.charrom_family = 0;
        b.charset_lowercase = 0;
        gfx_load_default_charrom(&b);
        b.screen_mode = GFX_SCREEN_BITMAP;

        for (const char *p = msg; *p; p++) {
            uint8_t sc = (uint8_t)*p;            /* screen code for "HI" */
            gfx_video_bitmap_stamp_glyph(&b, col, row, sc, 1);
            col++;
            if (col >= 40) { col = 0; row++; }
        }

        /* "H" is screencode 8 in C64 screen-code order (petscii_font[8]);
         * when gfx_put_byte runs CHR$('H') through gfx_ascii_to_screencode
         * it maps to the 'H' glyph. Rather than replicate that mapping
         * here, we confirm *something* non-zero landed in the cells and
         * that untouched cells remain zero. */
        {
            int any_h = 0, any_i = 0, any_other = 0;
            for (int gy = 0; gy < 8; gy++) {
                unsigned off = (unsigned)gy * 40u;
                if (b.bitmap[off + 0] != 0) any_h = 1;
                if (b.bitmap[off + 1] != 0) any_i = 1;
            }
            for (int gy = 0; gy < 8; gy++) {
                unsigned off = (unsigned)gy * 40u;
                if (b.bitmap[off + 2] != 0) any_other = 1;
                if (b.bitmap[off + 39] != 0) any_other = 1;
            }
            assert(any_h && any_i);
            assert(!any_other);
        }

        /* Clearing via gfx_video_bitmap_clear returns us to all-zero
         * without touching s->chars[]. */
        gfx_video_bitmap_clear(&b);
        for (size_t i = 0; i < sizeof(b.bitmap); i++) assert(b.bitmap[i] == 0);
        assert(b.chars[8 * 8] != 0 || b.chars[8 * 8 + 1] != 0 ||
               b.chars[8 * 8 + 2] != 0 || b.chars[8 * 8 + 3] != 0);
    }

    printf("gfx_video_test OK\n");
    return 0;
}

