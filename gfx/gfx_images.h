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

#endif /* GFX_IMAGES_H */
