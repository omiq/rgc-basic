1 REM ============================================================
2 REM Tutorial: JOY / JOYAXIS (basic-gfx native or canvas WASM)
3 REM Native: ./basic-gfx examples/tutorial_gfx_gamepad.bas
4 REM Canvas: connect a controller; see also examples/gfx_joy_demo.bas
5 REM Button codes 1-15 (Raylib); axes 0-5 scaled to about -1000..1000
6 REM ============================================================
10 PRINT "{CLR}{HOME}GAMEPAD — press buttons / move sticks"
20 PRINT "Port 0, Face A (code 7):"; JOY(0, 7)
30 PRINT "Left stick X (axis 0):"; JOYAXIS(0, 0)
40 PRINT "Left stick Y (axis 1):"; JOYAXIS(0, 1)
50 PRINT "(Values update each frame in a real game loop.)"
60 END
