' ============================================================
'  gfx_loadscreen_demo - PNG to SCREEN plane
'
'  LOADSCREEN path$ [, x [, y]]
'
'  Dispatches on the current SCREEN mode:
'    SCREEN 2 (RGBA)    - copies PNG as-is, full colour + alpha
'    SCREEN 3 (256-col) - quantises to the 256-entry palette via
'                         nearest-RGB match; alpha < 128 maps to
'                         the current BACKGROUND index
'    SCREEN 0/1         - not supported (needs dithering work)
'
'  Pairs with PALETTEROTATE for classic demoscene palette cycling
'  effects on a loaded PNG.
'
'  Keys: 2 = RGBA mode, 3 = indexed mode, SPACE cycle, Q quit
' ============================================================

FILE$ = "sky.png"
MODE = 3
DIRTY = 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("2")) THEN MODE = 2 : DIRTY = 1
  IF KEYPRESS(ASC("3")) THEN MODE = 3 : DIRTY = 1

  IF DIRTY = 1 THEN
    IF MODE = 2 THEN SCREEN 2 : BACKGROUNDRGB 0, 0, 0 ELSE SCREEN 3 : BACKGROUND 0
    CLS
    LOADSCREEN FILE$
    IF MODE = 2 THEN
      COLORRGB 255, 255, 0
    ELSE
      COLOR 7
    END IF
    DRAWTEXT 8, 8, "LOADSCREEN " + STR$(MODE), 1
    DRAWTEXT 8, 180, "2=RGBA 3=IDX SPACE=CYCLE Q=QUIT", 1
    DIRTY = 0
  END IF

  IF MODE = 3 AND KEYDOWN(ASC(" ")) THEN
    PALETTEROTATE 16, 255, 1
  END IF

  SLEEP 1
LOOP

PALETTERESET
