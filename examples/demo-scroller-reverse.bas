' ============================================================
'  demo-scroller-reverse.bas — Approach 5: GRADIENT-THROUGH-LETTERS
'                              scroller via DRAWTEXT reverse-video
'                              with transparent glyphs (2.1).
'
'  Paint a gradient band once, then each frame scroll a reverse-
'  video DRAWTEXT over it. The extended form
'    DRAWTEXT x, y, "{REVERSE ON}..." , fg, bg, 0, scale
'  with bg = -1 (transparent paper) means: fill each cell with
'  the fg colour BUT leave glyph pixels untouched — so whatever
'  was painted underneath reads through the letter shape.
'  Result: letters appear gradient-coloured (because the gradient
'  behind shows through), cell background is solid fg colour.
'
'  Classic demoscene "knockout" text effect, now a one-liner.
'
'  Keys: Q = quit
' ============================================================
ANTIALIAS OFF
SCREEN 2
BACKGROUNDRGB 10, 10, 28
CLS
DOUBLEBUFFER ON

BAND_Y = 80
BAND_H = 40

MSG$ = "       GRADIENT-THROUGH-LETTERS SCROLLER - THE GLYPHS ARE HOLES CUT THROUGH A SOLID CELL, THE GRADIENT BENEATH SHOWS THROUGH. WELCOME TO RGC-BASIC 2.1. "
LEN_MSG = LEN(MSG$)
SCROLL_X = 1

CELL_W = 16      ' scale-2 chargen = 16 px cells
TEXT_Y = BAND_Y

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Repaint the gradient band each frame BEHIND the knockout text.
  ' 40 LINEs/frame — cheap. Top = sky blue, bottom = deep purple.
  FOR Y = 0 TO BAND_H - 1
    T = Y / (BAND_H - 1.0)
    R = INT( 40 + T * 180 )
    G = INT(160 - T * 120 )
    B = INT(255 - T *  60 )
    COLORRGB R, G, B
    LINE 0, BAND_Y + Y TO 319, BAND_Y + Y
  NEXT

  ' Reverse-video DRAWTEXT with transparent bg (-1). Cells fill
  ' with solid black (COLOUR BLACK below); glyph pixels stay
  ' untouched = gradient shows through the letter shapes.
  DRAWTEXT SCROLL_X, TEXT_Y, "{REVERSE ON}" + MSG$, 0, -1, 0, 6

  SCROLL_X = SCROLL_X - 2
  IF SCROLL_X < -(LEN_MSG * CELL_W) THEN SCROLL_X = 320

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 5: gradient shows through letters"

  VSYNC
LOOP

DOUBLEBUFFER OFF
SCREEN 0
CLS
PRINT "Thanks for watching."
