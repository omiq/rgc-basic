' ============================================================
'  gfx_loadscreen_demo - PNG to SCREEN plane
'
'  LOADSCREEN path$ [, x [, y]]
'
'  Dispatches on the current SCREEN mode:
'    SCREEN 0 (text)    - cell-quantises to 1 fg + 1 bg hardware
'                         colour per cell + PETSCII block glyph.
'                         40x25 text grid, 16 hardware colours.
'    SCREEN 1 (1bpp)    - Floyd-Steinberg dithers to the 16 hardware
'                         colours, stores per-pixel index in the
'                         bitmap_color[] plane. 320x200 @ 16 colours.
'    SCREEN 2 (RGBA)    - copies PNG as-is, full colour + alpha.
'                         320x200 @ 16.7M colours + 8-bit alpha.
'    SCREEN 3 (256-col) - quantises to the 256-entry palette via
'                         nearest-RGB match; alpha < 128 maps to
'                         the current BACKGROUND index.
'                         320x200 @ 256 palette entries.
'    SCREEN 4 (hi-RGBA) - QB64-style desktop canvas. Same colour
'                         depth as SCREEN 2 with 4x the pixels.
'                         640x400 @ 16.7M colours + 8-bit alpha.
'
'  Pairs with PALETTEROTATE for classic demoscene palette cycling
'  effects on a loaded PNG (SCREEN 3 only).
'
'  Keys: 0/1/2/3/4 pick screen mode, SPACE cycle (mode 3), Q quit
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
  IF KEYPRESS(ASC("4")) THEN MODE = 4 : DIRTY = 1

  IF DIRTY = 1 THEN
    IF MODE = 0 THEN SCREEN 0 : BACKGROUND 0
    IF MODE = 1 THEN SCREEN 1 : BACKGROUND 0
    IF MODE = 2 THEN SCREEN 2 : BACKGROUNDRGB 0, 0, 0
    IF MODE = 3 THEN SCREEN 3 : BACKGROUND 0
    IF MODE = 4 THEN SCREEN 4 : BACKGROUNDRGB 0, 0, 0
    CLS
    LOADSCREEN "sky.png"

    ' --- per-mode resolution + palette description ---
    RES$ = ""
    PAL$ = ""
    IF MODE = 0 THEN RES$ = "40x25 text"    : PAL$ = "16 hardware colours"
    IF MODE = 1 THEN RES$ = "320x200 1bpp"  : PAL$ = "16 palette indices"
    IF MODE = 2 THEN RES$ = "320x200 RGBA"  : PAL$ = "16.7M colours + 8-bit alpha"
    IF MODE = 3 THEN RES$ = "320x200 indexed" : PAL$ = "256 palette entries"
    IF MODE = 4 THEN RES$ = "640x400 RGBA"  : PAL$ = "16.7M colours + 8-bit alpha"

    ' SCREEN 0 has no DRAWTEXT-on-bitmap path; the cell-quantised
    ' preview already fills the text grid. For every other mode
    ' stamp a two-line HUD + the key legend at the bottom. Keep
    ' the y positions inside the 200-row bitmap so they survive
    ' on SCREEN 1/2/3; SCREEN 4 (400 rows) still shows them at
    ' the top of the taller canvas.
    IF MODE = 0 THEN
      ' SCREEN 0 is a text grid — DRAWTEXT / FILLRECT don't apply.
      ' LOADSCREEN has already filled every cell with a PETSCII
      ' block glyph, so we overwrite three text rows with the HUD
      ' using LOCATE + PRINT. PAPER 0 + COLOR 1 gives the widely-
      ' supported "white on black" look per cell.
      PAPER 0 : COLOR 1
      LOCATE 0, 0  : PRINT "SCREEN " + STR$(MODE) + "   " + RES$ + "     "
      LOCATE 0, 1  : PRINT PAL$ + "                                "
      LOCATE 0, 24 : PRINT "0/1/2/3/4 MODE SPACE=CYCLE(3) Q=QUIT"
    ELSE
      ' DRAWTEXT uses transparent OR blend, so text over a photo is
      ' fiddly to read. Paint a black strip behind each HUD line
      ' first. Wider on SCREEN 4 (640 px) than 1/2/3 (320 px).
      HUDW = 320 : IF MODE = 4 THEN HUDW = 640
      IF MODE = 2 OR MODE = 4 THEN
        COLORRGB 0, 0, 0
      ELSE
        COLOR 0
      END IF
      FILLRECT 0,   4 TO HUDW - 1,  28
      FILLRECT 0, 176 TO HUDW - 1, 196

      IF MODE = 2 OR MODE = 4 THEN COLORRGB 255, 255, 0 ELSE COLOR 7
      DRAWTEXT 8,  8, "SCREEN " + STR$(MODE) + "   " + RES$, 1
      DRAWTEXT 8, 20, PAL$, 1
      DRAWTEXT 8, 180, "0/1/2/3/4 MODE  SPACE=CYCLE (3)  Q=QUIT", 1
    END IF
    DIRTY = 0
  END IF

  IF MODE = 3 AND KEYDOWN(ASC(" ")) THEN
    PALETTEROTATE 16, 255, 1
  END IF

  SLEEP 1
LOOP

PALETTERESET
