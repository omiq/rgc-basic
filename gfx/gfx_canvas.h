#ifndef GFX_CANVAS_H
#define GFX_CANVAS_H

#include "gfx_video.h"
#include <stddef.h>
#include <stdint.h>

/* Pack PETSCII text screen into RGBA8 (row-major). Width = cols*8 (320 or 640), height = 200. */
void gfx_canvas_render_rgba(const GfxVideoState *s, uint8_t *rgba, size_t rgba_bytes);

#endif
