/* Optional gamepad polling for basic-gfx (Raylib). WASM canvas: stubs return 0. */

#ifndef GFX_GAMEPAD_H
#define GFX_GAMEPAD_H

/* Button codes match Raylib GamepadButton (0 = UNKNOWN … use 1+ for faces/DPAD).
 * Axis codes match Raylib GamepadAxis (0–5). */
int gfx_gamepad_button_down(int port, int button_code);
/* Axis movement scaled to roughly -1000..1000 (float * 1000, truncated). */
int gfx_gamepad_axis_scaled(int port, int axis_code);

#endif
