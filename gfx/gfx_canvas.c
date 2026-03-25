#include "gfx_canvas.h"
#include <string.h>

#define CELL_W 8
#define CELL_H 8
#define SCREEN_ROWS 25

static const uint8_t gfx_c64_palette_rgb[16][3] = {
    {0x00, 0x00, 0x00},
    {0xFF, 0xFF, 0xFF},
    {0x88, 0x00, 0x00},
    {0xAA, 0xFF, 0xEE},
    {0xCC, 0x44, 0xCC},
    {0x00, 0xCC, 0x55},
    {0x00, 0x00, 0xAA},
    {0xEE, 0xEE, 0x77},
    {0xDD, 0x88, 0x55},
    {0x66, 0x44, 0x00},
    {0xFF, 0x77, 0x77},
    {0x33, 0x33, 0x33},
    {0x77, 0x77, 0x77},
    {0xAA, 0xFF, 0x66},
    {0x00, 0x88, 0xFF},
    {0xBB, 0xBB, 0xBB},
};

static const uint8_t petscii_font[256][8] = {
#include "petscii_font_upper_body.inc"
};

static const uint8_t petscii_font_lower[256][8] = {
#include "petscii_font_lower_body.inc"
};

void gfx_canvas_load_default_charrom(GfxVideoState *s)
{
    int i;
    if (!s) {
        return;
    }
    if (s->charset_lowercase) {
        memcpy(s->chars, petscii_font_lower, sizeof(petscii_font_lower));
        for (i = 0; i < 26; i++) {
            memcpy(&s->chars[(65 + i) * 8], &petscii_font[1 + i][0], 8);
        }
        memcpy(&s->chars[96 * 8], &petscii_font[96][0], 160 * 8);
    } else {
        memcpy(s->chars, petscii_font, sizeof(petscii_font));
    }
}

void gfx_canvas_render_rgba(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes)
{
    int row, col, y, x;
    int cols;
    size_t need;

    if (!s || !rgba) {
        return;
    }
    cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;
    need = (size_t)cols * CELL_W * (size_t)SCREEN_ROWS * CELL_H * 4u;
    if (rgba_bytes < need) {
        return;
    }

    for (row = 0; row < SCREEN_ROWS; row++) {
        for (col = 0; col < cols; col++) {
            int idx = row * cols + col;
            uint8_t sc = s->screen[idx];
            uint8_t ci = s->color[idx] & 0x0Fu;
            const uint8_t *glyph;
            const uint8_t *fg_rgb = gfx_c64_palette_rgb[ci];
            const uint8_t *bg_rgb = gfx_c64_palette_rgb[s->bg_color & 0x0Fu];
            int reversed = (sc & 0x80) ? 1 : 0;

            glyph = &s->chars[(uint8_t)(sc & 0x7Fu) * 8];

            for (y = 0; y < CELL_H; y++) {
                uint8_t bits = glyph[y];
                for (x = 0; x < CELL_W; x++) {
                    size_t px = (size_t)(col * CELL_W + x);
                    size_t py = (size_t)(row * CELL_H + y);
                    size_t off = (py * (size_t)(cols * CELL_W) + px) * 4u;
                    int on = (bits & (uint8_t)(0x80 >> x)) ? 1 : 0;
                    const uint8_t *c_fg = (on ^ reversed) ? fg_rgb : bg_rgb;
                    rgba[off + 0] = c_fg[0];
                    rgba[off + 1] = c_fg[1];
                    rgba[off + 2] = c_fg[2];
                    rgba[off + 3] = 0xFF;
                }
            }
        }
    }
}
