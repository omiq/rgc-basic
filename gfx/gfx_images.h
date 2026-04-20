/* gfx_images.h — blitter-style off-screen bitmap surfaces (1bpp).
 *
 * Phase 1 of docs/rgc-blitter-surface-spec.md. Slot 0 is bound to the
 * current visible bitmap (gfx_vs->bitmap). Slots 1..31 are caller-allocated
 * off-screen surfaces of any size. All slots use the same MSB-first 1bpp
 * packing as gfx_bitmap_get/set_pixel (width rounded up to a byte stride).
 *
 * Rectangular copy works in any direction (visible↔offscreen,
 * offscreen↔offscreen) as long as both surfaces are loaded. Overlapping
 * rects inside the same slot are handled via a temporary row buffer.
 */
#ifndef GFX_IMAGES_H
#define GFX_IMAGES_H

#include <stdint.h>
#include "gfx_video.h"

#define GFX_IMAGE_MAX_SLOTS 32
#define GFX_IMAGE_SLOT_VISIBLE 0

/* Called once after gfx_vs is created. Makes slot 0 address the visible
 * bitmap. Safe to call more than once — rebinds to the supplied state. */
void gfx_image_bind_visible(GfxVideoState *s);

/* Allocate a 1bpp surface of size w x h in the given slot (1..MAX-1).
 * Replaces whatever was there. Returns 0 on success, -1 on bad args. */
int gfx_image_new(int slot, int w, int h);

/* Allocate an RGBA surface (w * h * 4 bytes) in the given slot.
 * Replaces whatever was there — the slot becomes RGBA-only (its 1bpp
 * buffer is freed). Caller fills via gfx_image_rgba_buffer() — used by
 * the render-thread grab in gfx_raylib.c. */
int gfx_image_new_rgba(int slot, int w, int h);

/* Direct pointer to a slot's RGBA buffer (NULL if the slot has none).
 * Used by gfx_raylib.c's render-thread grab to memcpy from the
 * composited RenderTexture into the slot. */
uint8_t *gfx_image_rgba_buffer(int slot);

/* Opaque pointer to the GfxVideoState last bound by gfx_image_bind_visible.
 * Backends call this from gfx_grab_visible_rgba. Forward-declared so
 * callers that don't need the full gfx_video.h keep include surface small. */
struct GfxVideoState;
struct GfxVideoState *gfx_image_get_visible_state(void);

/* Free an off-screen surface. Slot 0 is a no-op; never frees the visible
 * bitmap. Returns 0 on success, -1 if slot out of range. */
int gfx_image_free(int slot);

/* 1bpp rectangular copy. Clips both source and destination rects to each
 * surface's bounds. Returns 0 on success, -1 if either slot is unloaded. */
int gfx_image_copy(int src_slot, int sx, int sy, int sw, int sh,
                   int dst_slot, int dx, int dy);

/* Surface dimensions — 0 if slot is unloaded. */
int gfx_image_width(int slot);
int gfx_image_height(int slot);

/* Save a slot to a 24-bit BMP file. 1bpp pixels get expanded: bit=1
 * writes 0xFFFFFF (white), bit=0 writes 0x000000 (black). Returns 0
 * on success, -1 on error (slot unloaded, can't open file, etc.). */
int gfx_image_save_bmp(int slot, const char *path);

/* Save a slot to a 32-bit RGBA PNG.
 *   - Slot 0 (visible bitmap): on-pixels take the current foreground
 *     palette entry (bitmap_fg), off-pixels take the current background
 *     (bg_color). Alpha = 255 everywhere (full screenshot).
 *   - Slots 1..31 (off-screen 1bpp masks): on-pixels become opaque
 *     white; off-pixels become fully transparent (alpha = 0). Useful
 *     for exporting a drawn sprite/UI panel with a transparent cut-out.
 * Returns 0 on success, -1 on error. */
int gfx_image_save_png(int slot, const char *path);

/* Extension-dispatched saver. Chooses PNG if path ends ".png", BMP
 * otherwise. Case-insensitive. */
int gfx_image_save(int slot, const char *path);

/* Load a PNG / BMP / JPG / etc. into the given slot as a 1bpp mask.
 * Pixels with luminance >= 128 become pen; others become background.
 * Alpha = 0 always maps to background. slot must be 1..MAX-1 (slot 0
 * is the visible bitmap and can't be reallocated by this path). */
int gfx_image_load(int slot, const char *path);

/* Load a PNG / BMP / JPG etc. into the SCREEN 3 indexed plane
 * (s->bitmap_color[]). Quantises each source pixel to the nearest
 * palette entry (Euclidean distance in RGB). Clips to 320×200 at
 * offset (dx, dy) — out-of-bounds pixels are dropped.
 *
 * Alpha < 128 maps to the current bg_color index. Returns 0 on
 * success, -1 on load / arg failure. */
int gfx_load_png_to_indexed(GfxVideoState *s, const char *path, int dx, int dy);

/* Load a PNG / BMP / JPG etc. into the SCREEN 2 RGBA plane
 * (s->bitmap_rgba). Clips to 320×200 at (dx, dy). Plane must be
 * allocated (SCREEN 2 was entered). Returns 0 on success, -1 on
 * load / arg failure. */
int gfx_load_png_to_rgba(GfxVideoState *s, const char *path, int dx, int dy);

#endif /* GFX_IMAGES_H */
