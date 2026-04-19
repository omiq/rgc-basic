' ============================================================
'  Tutorial: JOY / JOYAXIS  (basic-gfx native or canvas WASM)
'   Native: ./basic-gfx examples/tutorial_gfx_gamepad.bas
'   Canvas: connect a controller; see also examples/gfx_joy_demo.bas
'  Button codes 1-15 (Raylib); axes 0-5 scaled to about -1000..1000.
' ============================================================

PRINT "{CLR}{HOME}GAMEPAD - press buttons / move sticks"
PRINT "Port 0, Face A (code 7): "; JOY(0, 7)
PRINT "Left stick X (axis 0):   "; JOYAXIS(0, 0)
PRINT "Left stick Y (axis 1):   "; JOYAXIS(0, 1)
PRINT "(Values update each frame in a real game loop.)"
