/* gfx_video.h - Graphics/video memory model for RGC-BASIC gfx builds.
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
#define GFX_TEXT_BASE   0x0400u  /* screen RAM: 1000 bytes (40x25) or 2000 (80x25) */
#define GFX_TEXT_SIZE   2000u

#define GFX_COLOR_BASE  0xD800u  /* colour RAM: 1000 bytes (40x25) or 2000 (80x25) */
#define GFX_COLOR_SIZE  2000u

#define GFX_CHAR_BASE   0x3000u  /* 256 chars * 8 bytes = 2048 bytes */
#define GFX_CHAR_SIZE   (256u * 8u)

/* Keyboard state (host-provided): 256 bytes.
 * Currently mapped as ASCII-like key indices (e.g. 'A' = 65) for simple
 * polling from BASIC via PEEK. Non-zero means "down". */
#define GFX_KEY_BASE    0xDC00u
#define GFX_KEY_SIZE    256u

/* Simple monochrome bitmap: 320x200, 1 bit per pixel. */
#define GFX_BITMAP_BASE 0x2000u
#define GFX_BITMAP_WIDTH  320u
#define GFX_BITMAP_HEIGHT 200u
#define GFX_BITMAP_BYTES  ((GFX_BITMAP_WIDTH * GFX_BITMAP_HEIGHT) / 8u)

/* Display mode for basic-gfx (SCREEN 0 / SCREEN 1). */
#define GFX_SCREEN_TEXT   0u
#define GFX_SCREEN_BITMAP 1u

typedef struct GfxVideoState {
    /* Virtual POKE/PEEK bases (defaults match C64-style layout). Regions may overlap in
     * 16-bit space; gfx_peek() uses fixed priority (keyboard before colour when ranges
     * overlap — see gfx_peek in gfx_video.c). */
    uint16_t mem_text;
    uint16_t mem_color;
    uint16_t mem_char;
    uint16_t mem_key;
    uint16_t mem_bitmap;
    uint8_t screen[GFX_TEXT_SIZE];          /* Screen codes (40x25 or 80x25) */
    uint8_t color[GFX_COLOR_SIZE];          /* Colour indices (0-15 per cell) */
    uint8_t chars[GFX_CHAR_SIZE];           /* Character ROM / UDGs */
    uint8_t bitmap[GFX_BITMAP_BYTES];       /* 320x200 1bpp bitmap */
    uint8_t key_state[256];                 /* Simple keyboard state, 1 = down */
    uint8_t key_queue[64];                  /* Keypress FIFO (bytes), for INKEY$ */
    uint8_t key_q_head;
    uint8_t key_q_tail;
    uint32_t ticks60;                       /* 60 Hz tick counter (TI), wraps at 24h */
    uint8_t bg_color;                       /* Background colour index (0-15) */
    uint8_t bitmap_fg;                      /* Hi-res bitmap “pen” (0-15), COLOR in gfx build */
    uint8_t charset_lowercase;              /* 0=upper/graphics, 1=lower/upper */
    uint8_t charrom_family;                 /* 0=C64 PETSCII ROM, 1=Commodore PET 2K chargen */
    uint8_t cols;                           /* 40 or 80; columns per row */
    uint8_t screen_mode;                    /* GFX_SCREEN_TEXT or GFX_SCREEN_BITMAP */
    /* Viewport scroll (pixels): content is shifted left/up by these amounts when compositing. */
    int16_t scroll_x;
    int16_t scroll_y;
} GfxVideoState;

/* Advance 60 Hz jiffy counter (TI / TI$); wraps every 24h like C64. */
#define GFX_TICKS60_WRAP 5184000u
void gfx_video_advance_ticks60(GfxVideoState *s, uint32_t delta_ticks);

/* Initialise state to a clean default (all zeros). */
void gfx_video_init(GfxVideoState *s);

/* Apply a named layout: "c64" (default) or "pet" (screen at $8000, etc.). Returns 0 on success. */
int gfx_video_apply_memory_preset(GfxVideoState *s, const char *preset);

/* Set all bases at once (e.g. after validation). Returns 0 on success, -1 if ranges overlap or overflow 64K. */
int gfx_video_set_memory_bases(GfxVideoState *s,
    uint16_t text, uint16_t color, uint16_t chr, uint16_t key, uint16_t bitmap);

typedef enum {
    GFX_MEM_TEXT = 0,
    GFX_MEM_COLOR,
    GFX_MEM_CHAR,
    GFX_MEM_KEY,
    GFX_MEM_BITMAP
} GfxMemRegion;

/* Change one region’s base address (hex-friendly programs often use one custom screen address). */
int gfx_video_set_memory_base(GfxVideoState *s, GfxMemRegion region, uint32_t base);

/* Clear all video RAM (screen, colour, chars, bitmap) but leave input state. */
void gfx_video_clear(GfxVideoState *s);

/* Reset keyboard state. */
void gfx_video_clear_keys(GfxVideoState *s);

/* Virtualised PEEK/POKE for video-related address ranges.
 *
 * Regions may overlap in 16-bit space (e.g. C64 colour vs keyboard).
 *
 * RESOLUTION ORDER (fixed — do not reorder in gfx_video.c):
 *   1. text screen
 *   2. KEYBOARD  ← before colour RAM; GFX_KEY_BASE (0xDC00) is inside
 *                  the colour window [0xD800, 0xDFD0) so keyboard must
 *                  win the tie-break or PEEK(56320+n) returns colour data.
 *   3. colour RAM
 *   4. charset
 *   5. bitmap
 *
 * Addresses outside the defined ranges currently read as 0 and ignore writes.
 * This is intentional: the graphics build only defines semantics for its
 * own virtual “hardware” and leaves everything else to the core interpreter.
 */
uint8_t gfx_peek(const GfxVideoState *s, uint16_t addr);
void gfx_poke(GfxVideoState *s, uint16_t addr, uint8_t value);

/* Hi-res bitmap: 320×200, row-major, 40 bytes per row, MSB = left pixel in each byte. */
int gfx_bitmap_get_pixel(const GfxVideoState *s, unsigned x, unsigned y);
/* Set (on=1) or clear (on=0) one pixel; coordinates outside the bitmap are ignored. */
void gfx_bitmap_set_pixel(GfxVideoState *s, int x, int y, int on);
/* Bresenham line; each point is clipped (same semantics as PSET/PRESET). */
void gfx_bitmap_line(GfxVideoState *s, int x0, int y0, int x1, int y1, int on);

#endif /* GFX_VIDEO_H */

