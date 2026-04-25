#include "gfx_gamepad.h"

#if defined(GFX_VIDEO) && defined(__EMSCRIPTEN__)
#include <emscripten.h>
#include <stdint.h>
/* Filled by canvas.html from navigator.getGamepads() each animation frame.
 * Button indices follow the browser Gamepad API (Standard Gamepad layout), not Raylib enums. */
#define WASM_GP_MAX_PORTS   4
#define WASM_GP_MAX_BUTTONS 32
#define WASM_GP_MAX_AXES    8

static uint8_t wasm_gp_btn[WASM_GP_MAX_PORTS][WASM_GP_MAX_BUTTONS];
static int16_t wasm_gp_axis[WASM_GP_MAX_PORTS][WASM_GP_MAX_AXES];

EMSCRIPTEN_KEEPALIVE uint8_t *wasm_gamepad_buttons_ptr(int port)
{
    if (port < 0 || port >= WASM_GP_MAX_PORTS) {
        return NULL;
    }
    return wasm_gp_btn[port];
}

EMSCRIPTEN_KEEPALIVE int16_t *wasm_gamepad_axes_ptr(int port)
{
    if (port < 0 || port >= WASM_GP_MAX_PORTS) {
        return NULL;
    }
    return wasm_gp_axis[port];
}

/* Map Raylib GamepadButton to W3C "Standard Gamepad" button indices (Xbox-style). */
static int wasm_map_raylib_button(int rl)
{
    switch (rl) {
    case 0: return -1;
    case 1: return 12; /* D-pad up */
    case 2: return 15; /* D-pad right */
    case 3: return 13; /* D-pad down */
    case 4: return 14; /* D-pad left */
    case 5: return 3;  /* Y (top) */
    case 6: return 1;  /* B */
    case 7: return 0;  /* A */
    case 8: return 2;  /* X */
    case 9: return 4;  /* LB */
    case 10: return 6; /* LT (often analog; may be 0) */
    case 11: return 5; /* RB */
    case 12: return 7; /* RT */
    case 13: return 8; /* View / Back */
    case 14: return 16; /* Guide (Meta) when present */
    case 15: return 9; /* Menu / Start */
    case 16: return 10; /* L3 */
    case 17: return 11; /* R3 */
    default: return -1;
    }
}

int gfx_gamepad_button_down(int port, int button_code)
{
    int b;
    if (port < 0 || port >= WASM_GP_MAX_PORTS) {
        return 0;
    }
    b = wasm_map_raylib_button(button_code);
    if (b < 0 || b >= WASM_GP_MAX_BUTTONS) {
        return 0;
    }
    return wasm_gp_btn[port][b] ? 1 : 0;
}

int gfx_gamepad_axis_scaled(int port, int axis_code)
{
    int a;
    float f;
    if (port < 0 || port >= WASM_GP_MAX_PORTS) {
        return 0;
    }
    if (axis_code < 0 || axis_code > 5) {
        return 0;
    }
    /* Same ordering as Raylib: 0-1 left stick, 2-3 right, 4-5 triggers */
    a = axis_code;
    if (a >= WASM_GP_MAX_AXES) {
        return 0;
    }
    f = (float)wasm_gp_axis[port][a] / 32767.0f;
    if (f > 1.0f) {
        f = 1.0f;
    }
    if (f < -1.0f) {
        f = -1.0f;
    }
    return (int)(f * 1000.0f);
}

#elif defined(GFX_VIDEO)
#include "raylib.h"
#include <stdio.h>

int gfx_gamepad_button_down(int port, int button_code)
{
    static int probed = 0;
    if (!probed) {
        probed = 1;
        fprintf(stderr, "[JOY probe] avail(0)=%d avail(1)=%d name0=%s\n",
                IsGamepadAvailable(0), IsGamepadAvailable(1),
                IsGamepadAvailable(0) ? GetGamepadName(0) : "(none)");
    }
    if (port < 0 || port > 3) {
        return 0;
    }
    if (button_code < (int)GAMEPAD_BUTTON_UNKNOWN ||
        button_code > (int)GAMEPAD_BUTTON_RIGHT_THUMB) {
        return 0;
    }
    if (!IsGamepadAvailable(port)) {
        return 0;
    }
    return IsGamepadButtonDown(port, (GamepadButton)button_code) ? 1 : 0;
}

int gfx_gamepad_axis_scaled(int port, int axis_code)
{
    float f;
    if (port < 0 || port > 3) {
        return 0;
    }
    if (axis_code < 0 || axis_code > (int)GAMEPAD_AXIS_RIGHT_TRIGGER) {
        return 0;
    }
    if (!IsGamepadAvailable(port)) {
        return 0;
    }
    f = GetGamepadAxisMovement(port, (GamepadAxis)axis_code);
    if (f > 1.0f) {
        f = 1.0f;
    }
    if (f < -1.0f) {
        f = -1.0f;
    }
    return (int)(f * 1000.0f);
}

#else

int gfx_gamepad_button_down(int port, int button_code)
{
    (void)port;
    (void)button_code;
    return 0;
}

int gfx_gamepad_axis_scaled(int port, int axis_code)
{
    (void)port;
    (void)axis_code;
    return 0;
}

#endif
