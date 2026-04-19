' ============================================================
'  gfx_drawtext_scale_demo - DRAWTEXT with integer scale
'
'  DRAWTEXT x, y, text$ [, scale]    scale in 1..8 (clamped).
'  Pixel-doubles each source pixel into a scale×scale block
'  against the existing 8×8 chargen. Transparent background,
'  current pen, no fg/bg arg (waits on Font system).
'
'  Also demonstrates CLS x,y TO x2,y2 for rect-clear inside
'  a double-buffered frame - clears only the HUD band instead
'  of re-stamping everything.
'
'  Keys: Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
DOUBLEBUFFER ON

T = 0
CLS

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Titles at fixed positions - drawn once per frame with scale.
  COLOR 7  : DRAWTEXT   8,  4, "SCALE 1", 1
  COLOR 3  : DRAWTEXT   8, 16, "SCALE 2", 2
  COLOR 13 : DRAWTEXT   8, 36, "SCALE 3", 3
  COLOR 10 : DRAWTEXT   8, 64, "SCALE 4", 4

  ' Animated HUD band at the bottom - only clear that strip
  ' rather than wiping the whole plane each frame.
  CLS 0, 170 TO 319, 199
  COLOR 7
  DRAWTEXT  8, 176, "T=" + STR$(T), 1
  COLOR 14
  DRAWTEXT 120, 176, "CLS RECT + DRAWTEXT SCALE", 1
  COLOR 10
  DRAWTEXT 240, 190, "Q QUIT", 1

  VSYNC
  T = T + 1
LOOP
