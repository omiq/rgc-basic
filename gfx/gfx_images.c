/* gfx_images.c — 1bpp off-screen bitmap surfaces (blitter Phase 1).
 *
 * This file also owns STB_IMAGE_IMPLEMENTATION so every GFX target
 * (basic-gfx + basic-wasm-canvas + basic-wasm-raylib) links one copy
 * of stbi_load — previously that lived in gfx_software_sprites.c
 * which isn't in the raylib build, so gfx_image_load would have been
 * unresolved there. */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gfx_images.h"
#include "gfx_video.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

static void bmp_put_u16(uint8_t *dst, uint16_t v)
{
    dst[0] = (uint8_t)(v & 0xFF);
    dst[1] = (uint8_t)((v >> 8) & 0xFF);
}
static void bmp_put_u32(uint8_t *dst, uint32_t v)
{
    dst[0] = (uint8_t)(v & 0xFF);
    dst[1] = (uint8_t)((v >> 8) & 0xFF);
    dst[2] = (uint8_t)((v >> 16) & 0xFF);
    dst[3] = (uint8_t)((v >> 24) & 0xFF);
}

typedef struct {
    int loaded;
    int w, h;
    int stride;      /* bytes per row = (w + 7) / 8 */
    uint8_t *pixels; /* stride * h bytes */
    int owned;       /* 1 = allocated by us (must free); 0 = borrowed (visible) */
} GfxImageSlot;

static GfxImageSlot g_slots[GFX_IMAGE_MAX_SLOTS];

void gfx_image_bind_visible(GfxVideoState *s)
{
    GfxImageSlot *sl = &g_slots[GFX_IMAGE_SLOT_VISIBLE];
    if (sl->owned && sl->pixels) {
        free(sl->pixels);
        sl->pixels = NULL;
    }
    sl->loaded = (s != NULL);
    sl->w = s ? (int)GFX_BITMAP_WIDTH : 0;
    sl->h = s ? (int)GFX_BITMAP_HEIGHT : 0;
    sl->stride = s ? (int)(GFX_BITMAP_WIDTH / 8u) : 0;
    sl->pixels = s ? s->bitmap : NULL;
    sl->owned = 0;
}

int gfx_image_new(int slot, int w, int h)
{
    GfxImageSlot *sl;
    int stride;
    if (slot <= GFX_IMAGE_SLOT_VISIBLE || slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    if (w <= 0 || h <= 0) return -1;
    sl = &g_slots[slot];
    if (sl->owned && sl->pixels) {
        free(sl->pixels);
        sl->pixels = NULL;
    }
    stride = (w + 7) / 8;
    sl->pixels = (uint8_t *)calloc((size_t)stride * (size_t)h, 1);
    if (!sl->pixels) {
        sl->loaded = 0;
        return -1;
    }
    sl->loaded = 1;
    sl->w = w;
    sl->h = h;
    sl->stride = stride;
    sl->owned = 1;
    return 0;
}

int gfx_image_free(int slot)
{
    GfxImageSlot *sl;
    if (slot < 0 || slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    if (slot == GFX_IMAGE_SLOT_VISIBLE) return 0; /* never free visible */
    sl = &g_slots[slot];
    if (sl->owned && sl->pixels) free(sl->pixels);
    sl->pixels = NULL;
    sl->loaded = 0;
    sl->w = sl->h = sl->stride = 0;
    sl->owned = 0;
    return 0;
}

int gfx_image_width(int slot)
{
    if (slot < 0 || slot >= GFX_IMAGE_MAX_SLOTS) return 0;
    return g_slots[slot].loaded ? g_slots[slot].w : 0;
}

int gfx_image_height(int slot)
{
    if (slot < 0 || slot >= GFX_IMAGE_MAX_SLOTS) return 0;
    return g_slots[slot].loaded ? g_slots[slot].h : 0;
}


static int img_get_pixel(const GfxImageSlot *sl, int x, int y)
{
    int byte, bit;
    if (x < 0 || y < 0 || x >= sl->w || y >= sl->h) return 0;
    byte = y * sl->stride + (x >> 3);
    bit = 7 - (x & 7);
    return (sl->pixels[byte] >> bit) & 1;
}

static void img_set_pixel(GfxImageSlot *sl, int x, int y, int on)
{
    int byte, bit;
    uint8_t mask;
    if (x < 0 || y < 0 || x >= sl->w || y >= sl->h) return;
    byte = y * sl->stride + (x >> 3);
    bit = 7 - (x & 7);
    mask = (uint8_t)(1u << bit);
    if (on) sl->pixels[byte] |= mask;
    else    sl->pixels[byte] &= (uint8_t)~mask;
}

int gfx_image_copy(int src_slot, int sx, int sy, int sw, int sh,
                   int dst_slot, int dx, int dy)
{
    GfxImageSlot *src, *dst;
    int x, y;
    int overlapping;
    uint8_t *rowbuf = NULL;

    if (src_slot < 0 || src_slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    if (dst_slot < 0 || dst_slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    src = &g_slots[src_slot];
    dst = &g_slots[dst_slot];
    if (!src->loaded || !dst->loaded) return -1;
    if (sw <= 0 || sh <= 0) return 0;

    /* Clip source rect to source bounds. */
    if (sx < 0) { sw += sx; dx -= sx; sx = 0; }
    if (sy < 0) { sh += sy; dy -= sy; sy = 0; }
    if (sx + sw > src->w) sw = src->w - sx;
    if (sy + sh > src->h) sh = src->h - sy;
    /* Clip dest rect to dest bounds. */
    if (dx < 0) { sw += dx; sx -= dx; dx = 0; }
    if (dy < 0) { sh += dy; sy -= dy; dy = 0; }
    if (dx + sw > dst->w) sw = dst->w - dx;
    if (dy + sh > dst->h) sh = dst->h - dy;
    if (sw <= 0 || sh <= 0) return 0;

    /* Overlap handling: if same slot and rects overlap, stage one row at
     * a time through a scratch buffer. Simple; cost is one malloc. */
    overlapping = (src == dst) &&
                  !(dx + sw <= sx || sx + sw <= dx ||
                    dy + sh <= sy || sy + sh <= dy);
    if (overlapping) {
        rowbuf = (uint8_t *)malloc((size_t)sw);
        if (!rowbuf) return -1;
    }

    /* Choose row iteration direction so overlapping copies in the same
     * column still work if caller avoids a full rect overlap. For the
     * general overlapping case we already stage through rowbuf. */
    if (overlapping && dy > sy) {
        /* bottom-up */
        for (y = sh - 1; y >= 0; y--) {
            for (x = 0; x < sw; x++) {
                rowbuf[x] = (uint8_t)img_get_pixel(src, sx + x, sy + y);
            }
            for (x = 0; x < sw; x++) {
                img_set_pixel(dst, dx + x, dy + y, rowbuf[x]);
            }
        }
    } else if (overlapping) {
        for (y = 0; y < sh; y++) {
            for (x = 0; x < sw; x++) {
                rowbuf[x] = (uint8_t)img_get_pixel(src, sx + x, sy + y);
            }
            for (x = 0; x < sw; x++) {
                img_set_pixel(dst, dx + x, dy + y, rowbuf[x]);
            }
        }
    } else {
        for (y = 0; y < sh; y++) {
            for (x = 0; x < sw; x++) {
                img_set_pixel(dst, dx + x, dy + y, img_get_pixel(src, sx + x, sy + y));
            }
        }
    }

    if (rowbuf) free(rowbuf);
    return 0;
}

int gfx_image_save_bmp(int slot, const char *path)
{
    GfxImageSlot *sl;
    FILE *f;
    uint8_t header[54];
    uint8_t *row;
    int row_size, padded;
    int x, y;
    int w, h;

    if (slot < 0 || slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    sl = &g_slots[slot];
    if (!sl->loaded || !sl->pixels) return -1;
    if (!path || !path[0]) return -1;
    w = sl->w;
    h = sl->h;
    if (w <= 0 || h <= 0) return -1;

    /* BMP row size is 3*w rounded up to a multiple of 4. */
    row_size = 3 * w;
    padded = (row_size + 3) & ~3;

    memset(header, 0, sizeof(header));
    header[0] = 'B'; header[1] = 'M';
    bmp_put_u32(&header[2], (uint32_t)(54 + (uint32_t)padded * (uint32_t)h));
    bmp_put_u32(&header[10], 54); /* pixel data offset */
    bmp_put_u32(&header[14], 40); /* DIB header size */
    bmp_put_u32(&header[18], (uint32_t)w);
    bmp_put_u32(&header[22], (uint32_t)h); /* positive → bottom-up */
    bmp_put_u16(&header[26], 1);  /* planes */
    bmp_put_u16(&header[28], 24); /* bpp */
    /* compression, image size, x/y ppm, colors used, important colors — all 0 */

    f = fopen(path, "wb");
    if (!f) return -1;
    if (fwrite(header, 1, sizeof(header), f) != sizeof(header)) {
        fclose(f);
        return -1;
    }
    row = (uint8_t *)calloc((size_t)padded, 1);
    if (!row) { fclose(f); return -1; }
    /* BMP rows are written bottom-up. */
    for (y = h - 1; y >= 0; y--) {
        for (x = 0; x < w; x++) {
            int on = img_get_pixel(sl, x, y);
            uint8_t v = on ? 0xFF : 0x00;
            row[x * 3 + 0] = v; /* B */
            row[x * 3 + 1] = v; /* G */
            row[x * 3 + 2] = v; /* R */
        }
        if (fwrite(row, 1, (size_t)padded, f) != (size_t)padded) {
            free(row); fclose(f);
            return -1;
        }
    }
    free(row);
    fclose(f);
    return 0;
}

int gfx_image_load(int slot, const char *path)
{
    int w, h, channels;
    unsigned char *pixels;
    int x, y;
    GfxImageSlot *sl;
    if (!path || !path[0]) return -1;
    if (slot <= GFX_IMAGE_SLOT_VISIBLE || slot >= GFX_IMAGE_MAX_SLOTS) return -1;
    pixels = stbi_load(path, &w, &h, &channels, 4);
    if (!pixels) return -1;
    if (gfx_image_new(slot, w, h) != 0) {
        stbi_image_free(pixels);
        return -1;
    }
    sl = &g_slots[slot];
    /* Threshold to 1bpp: luminance >= 128 and alpha > 0 → pen.
     * Standard Rec.601 grey weights (299/587/114). Cheap enough for
     * a one-shot conversion; runtime games blit from the resulting
     * 1bpp buffer. */
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            unsigned char *px = pixels + ((size_t)y * (size_t)w + (size_t)x) * 4u;
            unsigned r = px[0], g = px[1], b = px[2], a = px[3];
            unsigned luma = (299u * r + 587u * g + 114u * b + 500u) / 1000u;
            int on = (a > 0 && luma >= 128u) ? 1 : 0;
            if (on) {
                int byte = y * sl->stride + (x >> 3);
                int bit = 7 - (x & 7);
                sl->pixels[byte] |= (uint8_t)(1u << bit);
            }
        }
    }
    stbi_image_free(pixels);
    return 0;
}
