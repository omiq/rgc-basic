#include "gfx_gamepad.h"

#if defined(GFX_VIDEO) && !defined(__EMSCRIPTEN__)
#include "raylib.h"

int gfx_gamepad_button_down(int port, int button_code)
{
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
