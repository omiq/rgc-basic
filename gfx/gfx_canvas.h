/* Headless PETSCII framebuffer → RGBA for browser canvas (no Raylib). */

#ifndef GFX_CANVAS_H
#define GFX_CANVAS_H

#include "gfx_video.h"
#include <stdint.h>

void gfx_canvas_load_default_charrom(GfxVideoState *s);
void gfx_canvas_render_rgba(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes);

#endif
