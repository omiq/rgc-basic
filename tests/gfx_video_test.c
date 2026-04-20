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

    /* ============================================================
     * Step 3: gfx_video_bitmap_scroll_up_cell. Shift bitmap up 8
     * pixel rows; bottom 8 rows cleared; text plane untouched.
     * ============================================================ */
    {
        GfxVideoState b;
        const unsigned row_bytes = GFX_BITMAP_WIDTH / 8u;

        gfx_video_init(&b);
        b.screen_mode = GFX_SCREEN_BITMAP;

        /* Paint each of the 200 pixel rows with a unique byte so we can
         * tell which row survived. Using (y & 0xFF) means rows 0 and 256
         * would alias, but height is 200 so every row value is unique. */
        for (unsigned y = 0; y < GFX_BITMAP_HEIGHT; y++) {
            memset(&b.bitmap[y * row_bytes], (int)(y & 0xFFu), row_bytes);
        }

        /* Put known content on the text plane to confirm the scroll
         * leaves it alone. */
        memset(b.screen, 'Z', sizeof(b.screen));

        gfx_video_bitmap_scroll_up_cell(&b);

        /* Rows 0..191 now carry the content of former rows 8..199. */
        for (unsigned y = 0; y < GFX_BITMAP_HEIGHT - 8u; y++) {
            uint8_t expected = (uint8_t)((y + 8u) & 0xFFu);
            for (unsigned x = 0; x < row_bytes; x++) {
                assert(b.bitmap[y * row_bytes + x] == expected);
            }
        }
        /* Rows 192..199 (the bottom cell) are zeroed. */
        for (unsigned y = GFX_BITMAP_HEIGHT - 8u; y < GFX_BITMAP_HEIGHT; y++) {
            for (unsigned x = 0; x < row_bytes; x++) {
                assert(b.bitmap[y * row_bytes + x] == 0);
            }
        }
        /* Text plane untouched. */
        for (size_t i = 0; i < sizeof(b.screen); i++) {
            assert(b.screen[i] == 'Z');
        }

        /* Repeated scrolls compose: after two more scrolls, rows 0..175
         * should hold former rows 24..199. */
        gfx_video_bitmap_scroll_up_cell(&b);
        gfx_video_bitmap_scroll_up_cell(&b);
        for (unsigned y = 0; y < GFX_BITMAP_HEIGHT - 24u; y++) {
            uint8_t expected = (uint8_t)((y + 24u) & 0xFFu);
            assert(b.bitmap[y * row_bytes] == expected);
        }
        for (unsigned y = GFX_BITMAP_HEIGHT - 24u; y < GFX_BITMAP_HEIGHT; y++) {
            assert(b.bitmap[y * row_bytes] == 0);
        }

        /* NULL tolerant. */
        gfx_video_bitmap_scroll_up_cell(NULL);
    }

    /* Multi-plane screen buffers: SCREEN BUFFER / DRAW / SHOW / FREE / SWAP / COPY. */
    {
        GfxVideoState b;
        gfx_video_init(&b);

        /* Defaults: slot 0 is bitmap[], slot 1 is bitmap_show[]; others NULL. */
        assert(b.screen_buffers[0] == b.bitmap);
        assert(b.screen_buffers[1] == b.bitmap_show);
        assert(b.screen_buffers[2] == NULL);
        assert(b.screen_draw == 0);
        assert(b.screen_show == 0);

        /* Allocation bounds: slots 0 and 1 are reserved, 2..7 only. */
        assert(gfx_video_screen_buffer_alloc(&b, 0) == -1);
        assert(gfx_video_screen_buffer_alloc(&b, 1) == -1);
        assert(gfx_video_screen_buffer_alloc(&b, 8) == -1);
        assert(gfx_video_screen_buffer_alloc(&b, 2) == 0);
        assert(b.screen_buffers[2] != NULL);
        assert(b.screen_buffer_owned[2] == 1);
        /* Idempotent. */
        assert(gfx_video_screen_buffer_alloc(&b, 2) == 0);

        /* Draw into slot 2 — bitmap[] must stay untouched. */
        assert(gfx_video_screen_set_draw(&b, 2) == 0);
        gfx_bitmap_set_pixel(&b, 5, 7, 1);
        assert(b.screen_buffers[2][7 * 40 + 0] == 0x04);
        assert(b.bitmap[7 * 40 + 0] == 0x00);
        assert(gfx_bitmap_get_pixel(&b, 5, 7) == 1);

        /* SHOW slot 2 — show plane reads slot 2. */
        assert(gfx_video_screen_set_show(&b, 2) == 0);
        assert(gfx_bitmap_get_show_pixel(&b, 5, 7) == 1);

        /* Retarget DRAW back to slot 0; show still reads slot 2. */
        assert(gfx_video_screen_set_draw(&b, 0) == 0);
        gfx_bitmap_set_pixel(&b, 0, 0, 1);
        assert(b.bitmap[0] == 0x80);
        assert(gfx_bitmap_get_show_pixel(&b, 0, 0) == 0); /* shown buffer unchanged */

        /* COPY slot 2 to slot 0 — merge the offscreen plane into the visible one. */
        assert(gfx_video_screen_copy(&b, 2, 0) == 0);
        assert(b.bitmap[7 * 40 + 0] == 0x04);

        /* SWAP draw, show atomically. */
        assert(gfx_video_screen_swap(&b, 2, 0) == 0);
        assert(b.screen_draw == 2);
        assert(b.screen_show == 0);

        /* FREE must refuse slot 0, 1, 8, or the active draw/show slot. */
        assert(gfx_video_screen_buffer_free(&b, 0) == -1);
        assert(gfx_video_screen_buffer_free(&b, 1) == -1);
        assert(gfx_video_screen_buffer_free(&b, 2) == -1); /* still draw */
        /* Move draw off slot 2, then free should succeed. */
        assert(gfx_video_screen_set_draw(&b, 0) == 0);
        assert(gfx_video_screen_buffer_free(&b, 2) == 0);
        assert(b.screen_buffers[2] == NULL);
        assert(b.screen_buffer_owned[2] == 0);

        /* VSYNC flip: with double_buffer and slots 0/1, draw -> show. */
        b.double_buffer = 1;
        gfx_video_screen_set_draw(&b, 0);
        gfx_video_screen_set_show(&b, 1);
        memset(b.bitmap, 0xAB, GFX_BITMAP_BYTES);
        memset(b.bitmap_show, 0x00, GFX_BITMAP_BYTES);
        gfx_video_bitmap_flip(&b);
        assert(b.bitmap_show[0] == 0xAB);
        assert(b.bitmap_show[GFX_BITMAP_BYTES - 1] == 0xAB);

        /* When draw == show, flip is a no-op (no self-copy). */
        gfx_video_screen_set_show(&b, 0);
        memset(b.bitmap, 0xCD, 1);
        gfx_video_bitmap_flip(&b);
        assert(b.bitmap[0] == 0xCD);
    }

    /* Scaled glyph stamp: a glyph that is solid in the top-left pixel
     * should fill a `scale × scale` block after stamp_glyph_px_scaled. */
    {
        GfxVideoState b;
        gfx_video_init(&b);
        /* Put a glyph whose top row is 0x80 (MSB only -> x=0 pixel set). */
        b.chars[0] = 0x80;
        b.chars[1] = 0x00;
        b.chars[2] = 0x00;
        b.chars[3] = 0x00;
        b.chars[4] = 0x00;
        b.chars[5] = 0x00;
        b.chars[6] = 0x00;
        b.chars[7] = 0x00;
        gfx_video_bitmap_stamp_glyph_px_scaled(&b, 0, 0, 0, 3);
        /* Expect a 3x3 block of set pixels at (0..2, 0..2) and zero beyond. */
        assert(gfx_bitmap_get_pixel(&b, 0, 0) == 1);
        assert(gfx_bitmap_get_pixel(&b, 2, 0) == 1);
        assert(gfx_bitmap_get_pixel(&b, 0, 2) == 1);
        assert(gfx_bitmap_get_pixel(&b, 2, 2) == 1);
        assert(gfx_bitmap_get_pixel(&b, 3, 0) == 0);
        assert(gfx_bitmap_get_pixel(&b, 0, 3) == 0);

        /* Scale clamps upward: 100 collapses to 8 without crashing. */
        memset(b.bitmap, 0, GFX_BITMAP_BYTES);
        gfx_video_bitmap_stamp_glyph_px_scaled(&b, 0, 0, 0, 100);
        assert(gfx_bitmap_get_pixel(&b, 7, 7) == 1);
        assert(gfx_bitmap_get_pixel(&b, 8, 0) == 0);

        /* Scale <= 1 delegates to non-scaled path (identity). */
        memset(b.bitmap, 0, GFX_BITMAP_BYTES);
        gfx_video_bitmap_stamp_glyph_px_scaled(&b, 0, 0, 0, 1);
        assert(gfx_bitmap_get_pixel(&b, 0, 0) == 1);
        assert(gfx_bitmap_get_pixel(&b, 1, 0) == 0);
    }

    /* Per-pixel colour plane (SCREEN 1 16-colour stamping): set_pixel
     * writes bitmap_fg into bitmap_color[y*W+x] on the main slot. */
    {
        GfxVideoState b;
        gfx_video_init(&b);
        b.bitmap_fg = 7;
        gfx_bitmap_set_pixel(&b, 10, 20, 1);
        assert(b.bitmap_color[20 * GFX_BITMAP_WIDTH + 10] == 7);
        b.bitmap_fg = 13;
        gfx_bitmap_set_pixel(&b, 30, 40, 1);
        assert(b.bitmap_color[40 * GFX_BITMAP_WIDTH + 30] == 13);
        /* Earlier stamp keeps its own colour — no retint. */
        assert(b.bitmap_color[20 * GFX_BITMAP_WIDTH + 10] == 7);
        /* Non-main slot does not touch the colour plane. */
        gfx_video_screen_buffer_alloc(&b, 2);
        gfx_video_screen_set_draw(&b, 2);
        b.bitmap_fg = 5;
        gfx_bitmap_set_pixel(&b, 0, 0, 1);
        assert(b.bitmap_color[0] == 0);
        gfx_video_screen_set_draw(&b, 0);
    }

    /* SCREEN 2 RGBA plane: alloc + set_pixel writes via the pen. */
    {
        GfxVideoState b;
        gfx_video_init(&b);
        assert(b.bitmap_rgba == NULL);
        assert(gfx_rgba_alloc(&b) == 0);
        assert(b.bitmap_rgba != NULL);
        assert(b.bitmap_rgba_show != NULL);

        b.pen_r = 255; b.pen_g = 128; b.pen_b = 64; b.pen_a = 200;
        gfx_rgba_set_pixel(&b, 5, 7);
        {
            unsigned off = (7 * GFX_BITMAP_WIDTH + 5) * 4u;
            assert(b.bitmap_rgba[off + 0] == 255);
            assert(b.bitmap_rgba[off + 1] == 128);
            assert(b.bitmap_rgba[off + 2] == 64);
            assert(b.bitmap_rgba[off + 3] == 200);
        }
        /* Clear uses bg RGBA, not pen. */
        b.bgrgba_r = 10; b.bgrgba_g = 20; b.bgrgba_b = 30; b.bgrgba_a = 255;
        gfx_rgba_clear(&b);
        {
            unsigned off = (7 * GFX_BITMAP_WIDTH + 5) * 4u;
            assert(b.bitmap_rgba[off + 0] == 10);
            assert(b.bitmap_rgba[off + 1] == 20);
            assert(b.bitmap_rgba[off + 2] == 30);
        }
        /* Scaled glyph stamp writes a scale*scale block. */
        b.chars[0] = 0x80;                     /* top-left pixel only */
        b.pen_r = 1; b.pen_g = 2; b.pen_b = 3; b.pen_a = 4;
        gfx_rgba_stamp_glyph_px_scaled(&b, 0, 0, 0, 3);
        assert(b.bitmap_rgba[0 + 0] == 1);
        assert(b.bitmap_rgba[(2 * GFX_BITMAP_WIDTH + 2) * 4 + 0] == 1);
        assert(b.bitmap_rgba[(3 * GFX_BITMAP_WIDTH + 3) * 4 + 0] != 1);
        /* NULL tolerant. */
        gfx_rgba_set_pixel(NULL, 0, 0);
    }

    /* Palette: writable table + reset. */
    {
        assert(gfx_c64_palette_rgb[0][0] == 0x00);
        assert(gfx_c64_palette_rgb[1][0] == 0xFF);
        gfx_c64_palette_rgb[1][0] = 0x12;
        gfx_c64_palette_rgb[1][1] = 0x34;
        gfx_c64_palette_rgb[1][2] = 0x56;
        gfx_c64_palette_rgb[1][3] = 0x78;
        assert(gfx_c64_palette_rgb[1][0] == 0x12);
        gfx_palette_reset();
        assert(gfx_c64_palette_rgb[1][0] == 0xFF);
        assert(gfx_c64_palette_rgb[1][1] == 0xFF);
        assert(gfx_c64_palette_rgb[1][2] == 0xFF);
        assert(gfx_c64_palette_rgb[1][3] == 0xFF);
    }

    printf("gfx_video_test OK\n");
    return 0;
}

