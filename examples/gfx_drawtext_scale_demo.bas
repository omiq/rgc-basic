' ============================================================
'  gfx_drawtext_scale_demo - DRAWTEXT with integer scale
'
'  DRAWTEXT x, y, text$ [, scale]    scale in 1..8 (clamped).
'  Pixel-doubles each source pixel into a scale×scale block
'  against the existing 8×8 chargen. Transparent background,
'  current pen.
'
'  NOTE on colour: the bitmap plane is 1 bit per pixel. COLOR
'  sets a single renderer-side pen register that tints every
'  lit bit at composite time, so CHANGING colour between
'  DRAWTEXT calls in the same frame re-tints the WHOLE plane
'  (not just the stamp you were about to draw). Per-stamp fg
'  waits on the Font system / blitter Phase 2 (RGBA surfaces).
'  This demo picks one pen and keeps it.
'
'  Also demonstrates CLS x,y TO x2,y2 - clears only the HUD
'  band at the bottom rather than wiping the whole plane each
'  frame.
'
'  Keys: Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
DOUBLEBUFFER ON
COLOR 14                   ' single pen for the whole frame

T = 0
CLS

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Titles at four scales - all drawn in COLOR 14 (bitmap is 1bpp).
  DRAWTEXT   8,  4, "SCALE 1", 1
  DRAWTEXT   8, 16, "SCALE 2", 2
  DRAWTEXT   8, 36, "SCALE 3", 3
  DRAWTEXT   8, 64, "SCALE 4", 4

  ' Animated HUD band at the bottom - partial CLS, same pen.
  CLS 0, 170 TO 319, 199
  DRAWTEXT   8, 176, "T=" + STR$(T), 1
  DRAWTEXT 120, 176, "CLS RECT + DRAWTEXT SCALE", 1
  DRAWTEXT 240, 190, "Q QUIT", 1

  VSYNC
  T = T + 1
LOOP
