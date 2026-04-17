#include "gfx_mouse.h"
#include <string.h>

#ifdef GFX_VIDEO

/* Edge latches updated once per host poll; BASIC reads stable values until next poll. */
static int32_t g_mx, g_my;
static uint8_t g_btn_cur[GFX_MOUSE_BTN_COUNT];
static uint8_t g_press_latch[GFX_MOUSE_BTN_COUNT];
static uint8_t g_release_latch[GFX_MOUSE_BTN_COUNT];
static int g_cursor_hidden;

#if !defined(__EMSCRIPTEN__) || defined(GFX_USE_RAYLIB)
#include "raylib.h"
/* Last letterboxed draw rect (window pixels) for inverse SetMousePosition. */
static float g_win_dx, g_win_dy, g_win_dw, g_win_dh;
static int g_fb_w = 320, g_fb_h = 200;
#endif

void gfx_mouse_init(void)
{
    memset(g_btn_cur, 0, sizeof(g_btn_cur));
    memset(g_press_latch, 0, sizeof(g_press_latch));
    memset(g_release_latch, 0, sizeof(g_release_latch));
    g_mx = 0;
    g_my = 0;
    g_cursor_hidden = 0;
#if !defined(__EMSCRIPTEN__) || defined(GFX_USE_RAYLIB)
    g_win_dx = 0;
    g_win_dy = 0;
    g_win_dw = 320;
    g_win_dh = 200;
    g_fb_w = 320;
    g_fb_h = 200;
#endif
}

static void gfx_mouse_apply_poll(int32_t mx, int32_t my, const uint8_t *new_down, int cw, int ch)
{
    int i;
    if (cw < 1) {
        cw = 320;
    }
    if (ch < 1) {
        ch = 200;
    }
    if (mx < 0) {
        mx = 0;
    }
    if (my < 0) {
        my = 0;
    }
    if (mx > cw - 1) {
        mx = cw - 1;
    }
    if (my > ch - 1) {
        my = ch - 1;
    }
    g_mx = mx;
    g_my = my;
    /* Sticky latches: OR-in every edge seen since the last BASIC read.
     * BASIC read (gfx_mouse_button_pressed / _released) consumes the latch.
     * Prevents a click being lost when multiple host polls happen between
     * two BASIC iterations (canvas WASM rAF poll vs BASIC DO...LOOP cadence). */
    for (i = 0; i < GFX_MOUSE_BTN_COUNT; i++) {
        uint8_t prev = g_btn_cur[i];
        uint8_t d = (new_down && i < GFX_MOUSE_BTN_COUNT) ? (new_down[i] ? 1u : 0u) : 0u;
        if (d && !prev) {
            g_press_latch[i] = 1u;
        }
        if (!d && prev) {
            g_release_latch[i] = 1u;
        }
        g_btn_cur[i] = d;
    }
}

int gfx_mouse_x(void)
{
    return (int)g_mx;
}

int gfx_mouse_y(void)
{
    return (int)g_my;
}

int gfx_mouse_button_pressed(int button)
{
    int v;
    if (button < 0 || button >= GFX_MOUSE_BTN_COUNT) {
        return 0;
    }
    v = g_press_latch[button] ? 1 : 0;
    g_press_latch[button] = 0u; /* consume: one observed edge per click */
    return v;
}

int gfx_mouse_button_down(int button)
{
    if (button < 0 || button >= GFX_MOUSE_BTN_COUNT) {
        return 0;
    }
    return g_btn_cur[button] ? 1 : 0;
}

int gfx_mouse_button_released(int button)
{
    int v;
    if (button < 0 || button >= GFX_MOUSE_BTN_COUNT) {
        return 0;
    }
    v = g_release_latch[button] ? 1 : 0;
    g_release_latch[button] = 0u; /* consume: one observed edge per release */
    return v;
}

int gfx_mouse_button_up(int button)
{
    if (button < 0 || button >= GFX_MOUSE_BTN_COUNT) {
        return 1;
    }
    return g_btn_cur[button] ? 0 : 1;
}

void gfx_mouse_set_position(int x, int y)
{
#if defined(__EMSCRIPTEN__) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>
    EM_ASM({
        var mx = $0 | 0;
        var my = $1 | 0;
        if (typeof Module !== 'undefined' && typeof Module['rgcMouseWarp'] === 'function') {
            Module['rgcMouseWarp'](mx, my);
        }
    }, x, y);
#else
    {
        float u, v;
        int wx, wy;
        if (g_fb_w < 2) {
            g_fb_w = 320;
        }
        if (g_fb_h < 2) {
            g_fb_h = 200;
        }
        u = (float)x / (float)(g_fb_w - 1);
        v = (float)y / (float)(g_fb_h - 1);
        if (u < 0.0f) {
            u = 0.0f;
        }
        if (u > 1.0f) {
            u = 1.0f;
        }
        if (v < 0.0f) {
            v = 0.0f;
        }
        if (v > 1.0f) {
            v = 1.0f;
        }
        wx = (int)(g_win_dx + u * g_win_dw + 0.5f);
        wy = (int)(g_win_dy + v * g_win_dh + 0.5f);
        SetMousePosition(wx, wy);
    }
#endif
    g_mx = x;
    g_my = y;
}

void gfx_mouse_set_cursor_shape(int cursor)
{
#if defined(__EMSCRIPTEN__) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>
    EM_ASM({
        var c = $0 | 0;
        if (typeof Module !== 'undefined' && typeof Module['rgcMouseSetCursor'] === 'function') {
            Module['rgcMouseSetCursor'](c);
        }
    }, cursor);
#else
    if (cursor < 0 || cursor > (int)MOUSE_CURSOR_POINTING_HAND) {
        cursor = (int)MOUSE_CURSOR_DEFAULT;
    }
    SetMouseCursor(cursor);
#endif
}

void gfx_mouse_hide_cursor(void)
{
    g_cursor_hidden = 1;
#if defined(__EMSCRIPTEN__) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>
    EM_ASM({
        if (typeof Module !== 'undefined' && typeof Module['rgcMouseHideCursor'] === 'function') {
            Module['rgcMouseHideCursor']();
        }
    });
#else
    HideCursor();
#endif
}

void gfx_mouse_show_cursor(void)
{
    g_cursor_hidden = 0;
#if defined(__EMSCRIPTEN__) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>
    EM_ASM({
        if (typeof Module !== 'undefined' && typeof Module['rgcMouseShowCursor'] === 'function') {
            Module['rgcMouseShowCursor']();
        }
    });
#else
    ShowCursor();
#endif
}

int gfx_mouse_cursor_hidden(void)
{
    return g_cursor_hidden ? 1 : 0;
}

#if defined(__EMSCRIPTEN__) && !defined(GFX_USE_RAYLIB)
#include <emscripten.h>

/* Called from JS each animation frame with content-space coords and button bits. */
EMSCRIPTEN_KEEPALIVE void wasm_mouse_js_frame(int mx, int my, int bl, int br, int bm, int cw, int ch)
{
    uint8_t down[GFX_MOUSE_BTN_COUNT];
    memset(down, 0, sizeof(down));
    if (bl) {
        down[GFX_MOUSE_BTN_LEFT] = 1;
    }
    if (br) {
        down[GFX_MOUSE_BTN_RIGHT] = 1;
    }
    if (bm) {
        down[GFX_MOUSE_BTN_MIDDLE] = 1;
    }
    gfx_mouse_apply_poll((int32_t)mx, (int32_t)my, down, cw, ch);
}

#else /* Raylib native */

void gfx_mouse_raylib_poll(int content_w, int content_h, float win_x0, float win_y0, float win_x1, float win_y1)
{
    Vector2 v = GetMousePosition();
    float mx = v.x;
    float my = v.y;
    float u, vv;
    int ix, iy;
    uint8_t down[GFX_MOUSE_BTN_COUNT];

    g_fb_w = content_w > 0 ? content_w : 320;
    g_fb_h = content_h > 0 ? content_h : 200;
    g_win_dx = win_x0;
    g_win_dy = win_y0;
    g_win_dw = win_x1 - win_x0;
    g_win_dh = win_y1 - win_y0;
    if (g_win_dw < 1.0f) {
        g_win_dw = 1.0f;
    }
    if (g_win_dh < 1.0f) {
        g_win_dh = 1.0f;
    }

    u = (mx - win_x0) / g_win_dw;
    vv = (my - win_y0) / g_win_dh;
    if (u < 0.0f) {
        u = 0.0f;
    }
    if (u > 1.0f) {
        u = 1.0f;
    }
    if (vv < 0.0f) {
        vv = 0.0f;
    }
    if (vv > 1.0f) {
        vv = 1.0f;
    }
    ix = (int)(u * (float)(g_fb_w - 1) + 0.5f);
    iy = (int)(vv * (float)(g_fb_h - 1) + 0.5f);

    memset(down, 0, sizeof(down));
    down[GFX_MOUSE_BTN_LEFT] = IsMouseButtonDown(MOUSE_BUTTON_LEFT) ? 1u : 0u;
    down[GFX_MOUSE_BTN_RIGHT] = IsMouseButtonDown(MOUSE_BUTTON_RIGHT) ? 1u : 0u;
    down[GFX_MOUSE_BTN_MIDDLE] = IsMouseButtonDown(MOUSE_BUTTON_MIDDLE) ? 1u : 0u;

    gfx_mouse_apply_poll((int32_t)ix, (int32_t)iy, down, g_fb_w, g_fb_h);
}

#endif /* __EMSCRIPTEN__ */

#endif /* GFX_VIDEO */
