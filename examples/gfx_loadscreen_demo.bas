' ============================================================
'  gfx_loadscreen_demo - PNG to SCREEN plane
'
'  LOADSCREEN path$ [, x [, y]]
'
'  Dispatches on the current SCREEN mode:
'    SCREEN 0 (text)    - cell-quantises to 1 fg + 1 bg hardware
'                         colour per cell + PETSCII block glyph
'    SCREEN 1 (1bpp)    - Floyd-Steinberg dithers to the 16 hardware
'                         colours, stores per-pixel index in the
'                         bitmap_color[] plane
'    SCREEN 2 (RGBA)    - copies PNG as-is, full colour + alpha
'    SCREEN 3 (256-col) - quantises to the 256-entry palette via
'                         nearest-RGB match; alpha < 128 maps to
'                         the current BACKGROUND index
'
'  Pairs with PALETTEROTATE for classic demoscene palette cycling
'  effects on a loaded PNG (SCREEN 3 only).
'
'  Keys: 0/1/2/3 pick screen mode, SPACE cycle (mode 3), Q quit
' ============================================================

' NOTE: LOADSCREEN path$ must use a literal quoted string so the
' IDE's asset auto-preload regex sees the filename and fetches
' sky.png into MEMFS before the program runs. A variable form
' (FILE$ = "sky.png" : LOADSCREEN FILE$) won't be scanned.

MODE = 3
DIRTY = 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("0")) THEN MODE = 0 : DIRTY = 1
  IF KEYPRESS(ASC("1")) THEN MODE = 1 : DIRTY = 1
  IF KEYPRESS(ASC("2")) THEN MODE = 2 : DIRTY = 1
  IF KEYPRESS(ASC("3")) THEN MODE = 3 : DIRTY = 1

  IF DIRTY = 1 THEN
    IF MODE = 0 THEN SCREEN 0 : BACKGROUND 0
    IF MODE = 1 THEN SCREEN 1 : BACKGROUND 0
    IF MODE = 2 THEN SCREEN 2 : BACKGROUNDRGB 0, 0, 0
    IF MODE = 3 THEN SCREEN 3 : BACKGROUND 0
    CLS
    LOADSCREEN "sky.png"
    IF MODE >= 1 THEN
      IF MODE = 2 THEN COLORRGB 255, 255, 0 ELSE COLOR 7
      DRAWTEXT 8, 8, "LOADSCREEN " + STR$(MODE), 1
      DRAWTEXT 8, 180, "0/1/2/3 MODE SPACE=CYCLE Q=QUIT", 1
    END IF
    DIRTY = 0
  END IF

  IF MODE = 3 AND KEYDOWN(ASC(" ")) THEN
    PALETTEROTATE 16, 255, 1
  END IF

  SLEEP 1
LOOP

PALETTERESET
