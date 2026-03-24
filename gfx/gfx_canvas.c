/* Canvas/WebGL-friendly RGBA framebuffer render for GfxVideoState (no Raylib). */

#include "gfx_video.h"
#include <stddef.h>
#include <string.h>

#define SCREEN_ROWS 25
#define CELL_W 8
#define CELL_H 8

static const uint8_t c64_rgb[16][3] = {
    {0x00, 0x00, 0x00}, {0xFF, 0xFF, 0xFF}, {0x88, 0x00, 0x00}, {0xAA, 0xFF, 0xEE},
    {0xCC, 0x44, 0xCC}, {0x00, 0xCC, 0x55}, {0x00, 0x00, 0xAA}, {0xEE, 0xEE, 0x77},
    {0xDD, 0x88, 0x55}, {0x66, 0x44, 0x00}, {0xFF, 0x77, 0x77}, {0x33, 0x33, 0x33},
    {0x77, 0x77, 0x77}, {0xAA, 0xFF, 0x66}, {0x00, 0x88, 0xFF}, {0xBB, 0xBB, 0xBB},
};

/* 320×200 RGBA8, row-major. Clamps to buffer size. */
void gfx_canvas_render_rgba(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes)
{
    int cols;
    int row, col, y, x;
    uint8_t bg_r, bg_g, bg_b;
    size_t need;

    if (!s || !rgba) {
        return;
    }
    cols = (s->cols == 80) ? 80 : 40;
    need = (size_t)(cols * CELL_W) * (size_t)(SCREEN_ROWS * CELL_H) * 4u;
    if (rgba_bytes < need) {
        return;
    }

    bg_r = c64_rgb[s->bg_color & 0x0F][0];
    bg_g = c64_rgb[s->bg_color & 0x0F][1];
    bg_b = c64_rgb[s->bg_color & 0x0F][2];
    memset(rgba, 0, need);
    {
        size_t i;
        for (i = 0; i < need; i += 4) {
            rgba[i + 0] = bg_r;
            rgba[i + 1] = bg_g;
            rgba[i + 2] = bg_b;
            rgba[i + 3] = 0xFF;
        }
    }

    for (row = 0; row < SCREEN_ROWS; row++) {
        for (col = 0; col < cols; col++) {
            int idx = row * cols + col;
            uint8_t sc = s->screen[idx];
            uint8_t ci = s->color[idx] & 0x0F;
            uint8_t fr, fg, fb, br, bgc, bb;
            const uint8_t *glyph;
            int reversed = (sc & 0x80) ? 1 : 0;

            fr = c64_rgb[ci][0];
            fg = c64_rgb[ci][1];
            fb = c64_rgb[ci][2];
            br = bg_r;
            bgc = bg_g;
            bb = bg_b;

            glyph = &s->chars[(uint8_t)(sc & 0x7F) * 8];

            for (y = 0; y < CELL_H; y++) {
                uint8_t bits = glyph[y];
                for (x = 0; x < CELL_W; x++) {
                    int px = col * CELL_W + x;
                    int py = row * CELL_H + y;
                    size_t off = ((size_t)py * (size_t)(cols * CELL_W) + (size_t)px) * 4u;
                    int on = (bits & (0x80 >> x)) ? 1 : 0;
                    uint8_t r, g, b;
                    if (on ^ reversed) {
                        r = fr; g = fg; b = fb;
                    } else {
                        r = br; g = bgc; b = bb;
                    }
                    rgba[off + 0] = r;
                    rgba[off + 1] = g;
                    rgba[off + 2] = b;
                    rgba[off + 3] = 0xFF;
                }
            }
        }
    }
}
