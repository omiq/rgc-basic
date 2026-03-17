/* gfx_video.h - Graphics/video memory model for CBM-BASIC gfx builds.
 *
 * This module is deliberately raylib-free and purely in-memory so it can be
 * tested headless. A separate front-end (e.g. gfx_raylib.c) can render from
 * this state.
 */

#ifndef GFX_VIDEO_H
#define GFX_VIDEO_H

#include <stdint.h>
#include <stddef.h>

/* Virtual address layout (C64-inspired, but not a full emulator). */
#define GFX_TEXT_BASE   0x0400u  /* 40x25 screen RAM: 1000 bytes */
#define GFX_TEXT_SIZE   1000u

#define GFX_COLOR_BASE  0xD800u  /* 40x25 colour RAM: 1000 bytes */
#define GFX_COLOR_SIZE  1000u

#define GFX_CHAR_BASE   0x3000u  /* 256 chars * 8 bytes = 2048 bytes */
#define GFX_CHAR_SIZE   (256u * 8u)

/* Simple monochrome bitmap: 320x200, 1 bit per pixel. */
#define GFX_BITMAP_BASE 0x2000u
#define GFX_BITMAP_WIDTH  320u
#define GFX_BITMAP_HEIGHT 200u
#define GFX_BITMAP_BYTES  ((GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT) / 8u)

typedef struct GfxVideoState {
    uint8_t screen[GFX_TEXT_SIZE];          /* Screen codes (40x25) */
    uint8_t color[GFX_COLOR_SIZE];          /* Colour indices (0-15 per cell) */
    uint8_t chars[GFX_CHAR_SIZE];           /* Character ROM / UDGs */
    uint8_t bitmap[GFX_BITMAP_BYTES];       /* 320x200 1bpp bitmap */
    uint8_t key_state[256];                 /* Simple keyboard state, 1 = down */
} GfxVideoState;

/* Initialise state to a clean default (all zeros). */
void gfx_video_init(GfxVideoState *s);

/* Clear all video RAM (screen, colour, chars, bitmap) but leave input state. */
void gfx_video_clear(GfxVideoState *s);

/* Reset keyboard state. */
void gfx_video_clear_keys(GfxVideoState *s);

/* Virtualised PEEK/POKE for video-related address ranges.
 *
 * Addresses outside the defined ranges currently read as 0 and ignore writes.
 * This is intentional: the graphics build only defines semantics for its
 * own virtual “hardware” and leaves everything else to the core interpreter.
 */
uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr);
void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value);

#endif /* GFX_VIDEO_H */

