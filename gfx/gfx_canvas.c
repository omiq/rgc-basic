/*
 * FEATURE FREEZE (as of 2026-04-17): this CPU software renderer powers the
 * current WASM build (basic-canvas.js/.wasm). It is scheduled to be replaced
 * by the raylib-emscripten WebGL2 path — see docs/wasm-webgl-migration-plan.md.
 *
 * Policy while the migration is in progress:
 *   - BUG FIXES ONLY: crashes, miscompiled rendering of existing features,
 *     security issues, build breakage.
 *   - NO new BASIC graphics features here. New sprite / bitmap / text / font
 *     / input / audio features land in gfx/gfx_raylib.c only.
 *   - NO refactors or "while I'm here" cleanups.
 *   - Users who need new features must run under the raylib-emscripten build
 *     (?renderer=raylib) once that ships.
 *
 * Removal target: ~3 months after raylib-emscripten becomes the default web
 * renderer and is proven stable.
 */

#include "gfx_canvas.h"
#include "gfx_charrom.h"
#include "gfx_software_sprites.h"
#include "gfx_images.h"
#include <stdlib.h>
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

void gfx_canvas_load_default_charrom(GfxVideoState *s)
{
    /* Same ROM layout as basic-gfx (gfx_load_default_charrom in gfx_charrom.c). */
    gfx_load_default_charrom(s);
}

static void render_text_layer(const GfxVideoState *s, uint8_t *rgba, int fb_w, int fb_h)
{
    int row, col, y, x;
    int cols;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    (void)fb_h;

    cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;

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
                    int px = col * CELL_W + x - sx;
                    int py = row * CELL_H + y - sy;
                    size_t off;
                    int on = (bits & (uint8_t)(0x80 >> x)) ? 1 : 0;
                    const uint8_t *c_fg = (on ^ reversed) ? fg_rgb : bg_rgb;
                    if (px < 0 || px >= fb_w || py < 0 || py >= fb_h) {
                        continue;
                    }
                    off = ((size_t)py * (size_t)fb_w + (size_t)px) * 4u;
                    rgba[off + 0] = c_fg[0];
                    rgba[off + 1] = c_fg[1];
                    rgba[off + 2] = c_fg[2];
                    rgba[off + 3] = 0xFF;
                }
            }
        }
    }
}

static void render_bitmap_layer(const GfxVideoState *s, uint8_t *rgba, int fb_w, int fb_h)
{
    const uint8_t *fg_rgb = gfx_c64_palette_rgb[s->bitmap_fg & 0x0Fu];
    const uint8_t *bg_rgb = gfx_c64_palette_rgb[s->bg_color & 0x0Fu];
    int off_x = (fb_w - (int)GFX_BITMAP_WIDTH) / 2;
    int sx = (int)s->scroll_x;
    int sy = (int)s->scroll_y;
    int y, x;

    if (off_x < 0) {
        off_x = 0;
    }

    for (y = 0; y < (int)GFX_BITMAP_HEIGHT && y < fb_h; y++) {
        for (x = 0; x < (int)GFX_BITMAP_WIDTH; x++) {
            int dx = off_x + x - sx;
            int dy = y - sy;
            int on;
            size_t off;
            if (dx < 0 || dx >= fb_w || dy < 0 || dy >= fb_h) {
                continue;
            }
            on = gfx_bitmap_get_show_pixel(s, (unsigned)x, (unsigned)y);
            off = ((size_t)dy * (size_t)fb_w + (size_t)dx) * 4u;
            if (on) {
                rgba[off + 0] = fg_rgb[0];
                rgba[off + 1] = fg_rgb[1];
                rgba[off + 2] = fg_rgb[2];
            } else {
                rgba[off + 0] = bg_rgb[0];
                rgba[off + 1] = bg_rgb[1];
                rgba[off + 2] = bg_rgb[2];
            }
            rgba[off + 3] = 0xFF;
        }
    }
}

void gfx_canvas_render_rgba(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes)
{
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

    if (s->screen_mode == GFX_SCREEN_BITMAP) {
        render_bitmap_layer(s, rgba, cols * CELL_W, SCREEN_ROWS * CELL_H);
    } else {
        render_text_layer(s, rgba, cols * CELL_W, SCREEN_ROWS * CELL_H);
    }
}

/* Full framebuffer: 80-col safe (640×200), then sprites (same order as Raylib). */
void gfx_canvas_render_full_frame(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes)
{
    int fb_w, fb_h;
    size_t need;
    int cols;

    if (!s || !rgba) {
        return;
    }
    cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;
    fb_w = cols * CELL_W;
    fb_h = SCREEN_ROWS * CELL_H;
    need = (size_t)fb_w * (size_t)fb_h * 4u;
    if (rgba_bytes < need) {
        return;
    }

    memset(rgba, 0, need);

    if (s->screen_mode == GFX_SCREEN_BITMAP) {
        render_bitmap_layer(s, rgba, fb_w, fb_h);
    } else {
        render_text_layer(s, rgba, fb_w, fb_h);
    }

    /* Skip software sprite composite when JS Canvas2D backend is active. */
    if (!gfx_sprite_js_backend_active()) {
        gfx_canvas_sprite_composite_rgba(s, rgba, fb_w, fb_h);
    } else {
        /* Still need to drain the command queue so slot state stays current. */
        gfx_sprite_process_queue();
    }
}

/* IMAGE GRAB from the visible framebuffer into slot, returning a full
 * RGBA snapshot (bitmap + text + sprites, resolved through gfx_canvas's
 * CPU compositor). Matches the semantics of gfx_raylib.c's cross-thread
 * grab: caller gets colour + alpha, not a 1bpp mask. Canvas build is
 * single-threaded (asyncify) so we can composite inline — no mutex. */
int gfx_grab_visible_rgba(int slot, int sx, int sy, int sw, int sh)
{
    struct GfxVideoState *s = gfx_image_get_visible_state();
    int fb_w, fb_h;
    int cols;
    uint8_t *frame;
    uint8_t *dst;
    int y;

    if (!s) return -1;
    if (sw <= 0 || sh <= 0) return -1;
    cols = (s->cols == 40 || s->cols == 80) ? (int)s->cols : 40;
    fb_w = cols * CELL_W;
    fb_h = SCREEN_ROWS * CELL_H;

    frame = (uint8_t *)malloc((size_t)fb_w * (size_t)fb_h * 4u);
    if (!frame) return -1;
    gfx_canvas_render_full_frame(s, frame, (size_t)fb_w * (size_t)fb_h * 4u);

    if (gfx_image_new_rgba(slot, sw, sh) != 0) {
        free(frame);
        return -1;
    }
    dst = gfx_image_rgba_buffer(slot);
    memset(dst, 0, (size_t)sw * (size_t)sh * 4u);
    for (y = 0; y < sh; y++) {
        int isy = sy + y;
        int x0, x1;
        if (isy < 0 || isy >= fb_h) continue;
        x0 = sx;
        x1 = sx + sw;
        if (x0 < 0) x0 = 0;
        if (x1 > fb_w) x1 = fb_w;
        if (x1 <= x0) continue;
        memcpy(dst + ((size_t)y * (size_t)sw + (size_t)(x0 - sx)) * 4u,
               frame + ((size_t)isy * (size_t)fb_w + (size_t)x0) * 4u,
               (size_t)(x1 - x0) * 4u);
    }
    free(frame);
    return 0;
}
