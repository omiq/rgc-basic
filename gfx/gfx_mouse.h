#ifndef GFX_MOUSE_H
#define GFX_MOUSE_H

#include <stdint.h>

/* Mouse button indices for IsMouseButton* (Raylib-compatible: 0=left, 1=right, 2=middle). */
#define GFX_MOUSE_BTN_LEFT   0
#define GFX_MOUSE_BTN_RIGHT  1
#define GFX_MOUSE_BTN_MIDDLE 2
#define GFX_MOUSE_BTN_COUNT  8

#ifdef GFX_VIDEO

void gfx_mouse_init(void);

/* Content-space pixel coords (0..fb_w-1, 0..fb_h-1) — same space as PSET / sprites. */
int gfx_mouse_x(void);
int gfx_mouse_y(void);

int gfx_mouse_button_pressed(int button);
int gfx_mouse_button_down(int button);
int gfx_mouse_button_released(int button);
int gfx_mouse_button_up(int button);

void gfx_mouse_set_position(int x, int y);
/* Raylib MouseCursor enum values (0 = default). WASM: host maps to CSS cursor. */
void gfx_mouse_set_cursor_shape(int cursor);
void gfx_mouse_hide_cursor(void);
void gfx_mouse_show_cursor(void);
int gfx_mouse_cursor_hidden(void);

#if defined(__EMSCRIPTEN__) && defined(GFX_VIDEO) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>
EMSCRIPTEN_KEEPALIVE void wasm_mouse_js_frame(int mx, int my, int left, int right, int middle, int fb_w, int fb_h);
#endif

#if defined(GFX_VIDEO) && (!defined(__EMSCRIPTEN__) || defined(GFX_USE_RAYLIB))
/* Called from Raylib main thread each frame before worker reads mouse.
 * Available in native raylib builds AND raylib-emscripten (WebGL2) WASM builds. */
void gfx_mouse_raylib_poll(int content_w, int content_h, float win_x0, float win_y0, float win_x1, float win_y1);
#endif

#else /* !GFX_VIDEO */

static inline int gfx_mouse_x(void) { return 0; }
static inline int gfx_mouse_y(void) { return 0; }
static inline int gfx_mouse_button_pressed(int b) { (void)b; return 0; }
static inline int gfx_mouse_button_down(int b) { (void)b; return 0; }
static inline int gfx_mouse_button_released(int b) { (void)b; return 0; }
static inline int gfx_mouse_button_up(int b) { (void)b; return 1; }
static inline void gfx_mouse_set_position(int x, int y) { (void)x; (void)y; }
static inline void gfx_mouse_set_cursor_shape(int c) { (void)c; }
static inline void gfx_mouse_hide_cursor(void) {}
static inline void gfx_mouse_show_cursor(void) {}
static inline int gfx_mouse_cursor_hidden(void) { return 0; }

#endif

#endif
