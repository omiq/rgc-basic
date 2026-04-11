#ifndef GFX_CHARROM_H
#define GFX_CHARROM_H

#include "gfx_video.h"
#include <stdint.h>

extern const uint8_t petscii_font[256][8];
extern const uint8_t petscii_font_lower[256][8];
extern const uint8_t pet_chargen_901447_10m[2048];

void gfx_load_default_charrom(GfxVideoState *s);

#endif
