/* Software sprite compositing for WASM canvas / headless (see gfx_software_sprites.c). */

#ifndef GFX_SOFTWARE_SPRITES_H
#define GFX_SOFTWARE_SPRITES_H

#include "gfx_video.h"
#include <stdint.h>

void gfx_sprite_process_queue(void);
void gfx_sprite_shutdown(void);

/* Alpha-composite active DRAWSPRITE slots (after text/bitmap layer is in rgba). */
void gfx_canvas_sprite_composite_rgba(const GfxVideoState *s, uint8_t *rgba, int fb_w, int fb_h);

#endif
