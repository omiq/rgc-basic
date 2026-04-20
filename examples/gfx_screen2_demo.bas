' ============================================================
'  gfx_screen2_demo - SCREEN 2 RGBA primitives
'
'  SCREEN 2 allocates a 320x200 RGBA plane (256 KB + a second
'  256 KB for DOUBLEBUFFER). All draw primitives write full
'  RGBA: PSET, LINE, RECT, FILLRECT, CIRCLE, FILLCIRCLE, CLS,
'  DRAWTEXT, PRINT.
'
'  Pen control:
'    COLOR n           - palette index 0..15 (also sets RGBA pen)
'    COLORRGB r,g,b    - full RGB, 0..255 each
'    COLORRGB r,g,b,a  - with alpha
'    BACKGROUNDRGB ... - CLS fill colour
'
'  Keys: Q quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 20, 20, 40
CLS

' Gradient bar - 256 RGB pens on the same frame.
FOR I = 0 TO 255
  COLORRGB I, 255 - I, 128
  LINE I + 32, 20 TO I + 32, 40
NEXT I

' Filled shapes with arbitrary colours.
COLORRGB 255, 180, 0   : FILLCIRCLE 80, 100, 24
COLORRGB 0, 200, 255   : FILLCIRCLE 140, 100, 24
COLORRGB 220, 80, 255  : FILLCIRCLE 200, 100, 24
COLORRGB 80, 255, 120  : FILLCIRCLE 260, 100, 24

' Outlines in a separate colour.
COLORRGB 255, 255, 255
CIRCLE 80, 100, 24
CIRCLE 140, 100, 24
CIRCLE 200, 100, 24
CIRCLE 260, 100, 24

' DRAWTEXT at three scales, one pen.
COLORRGB 255, 230, 100
DRAWTEXT  8,   4, "SCREEN 2 - RGBA", 1
DRAWTEXT  8, 140, "FULL COLOUR", 2
COLORRGB 255, 80, 80
DRAWTEXT  8, 180, "Q = QUIT", 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 1
LOOP
