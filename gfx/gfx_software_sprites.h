/* Software sprite compositing for WASM canvas / headless (see gfx_software_sprites.c). */

#ifndef GFX_SOFTWARE_SPRITES_H
#define GFX_SOFTWARE_SPRITES_H

#include "gfx_video.h"
#include <stdint.h>

void gfx_sprite_process_queue(void);
void gfx_sprite_shutdown(void);
void gfx_sprite_enqueue_copy(int src_slot, int dst_slot);

/* Alpha-composite active DRAWSPRITE slots (after text/bitmap layer is in rgba). */
void gfx_canvas_sprite_composite_rgba(const GfxVideoState *s, uint8_t *rgba, int fb_w, int fb_h);

/* JS Canvas2D sprite accessor API — used by WASM canvas build. */
unsigned char *gfx_sprite_slot_rgba_ptr(int slot);
int gfx_sprite_slot_w(int slot);
int gfx_sprite_slot_h(int slot);
int gfx_sprite_slot_draw_active(int slot);
int gfx_sprite_slot_draw_params(int slot,
    float *out_x, float *out_y, int *out_z,
    int *out_dw, int *out_dh,
    int *out_ma, int *out_mr, int *out_mg, int *out_mb,
    float *out_sx, float *out_sy);
unsigned int gfx_sprite_slot_version(int slot);
void gfx_sprite_slot_bump_version(int slot);
int  gfx_sprite_js_backend_active(void);
void gfx_sprite_set_js_backend(int enable);

#endif
