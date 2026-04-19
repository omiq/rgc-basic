' ============================================================
'  gfx_antialias_demo - ANTIALIAS ON/OFF toggle
'
'  Upscales a 32x32 ship to 4x (128x128) so the filter-mode
'  difference is obvious. Press SPACE to flip between POINT
'  (crisp pixels, retro) and BILINEAR (smoothed). Current mode
'  is printed on screen.
'
'  Keys: SPACE toggle, Q quit
' ============================================================

SPRITE LOAD 0, "ship.png"
' scale x4 - big enough that filter choice matters
SPRITEMODULATE 0, 255, 255, 255, 255, 4, 4

AA = 0
ANTIALIAS OFF

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN
    AA = 1 - AA
    IF AA = 1 THEN ANTIALIAS ON ELSE ANTIALIAS OFF
  END IF

  CLS
  DRAWSPRITE 0, 96, 36, 10
  DRAWTEXT   8,   8, "ANTIALIAS TEST"
  IF AA = 1 THEN DRAWTEXT 8, 24, "MODE: ON  (BILINEAR)"
  IF AA = 0 THEN DRAWTEXT 8, 24, "MODE: OFF (NEAREST)"
  DRAWTEXT   8, 180, "SPACE TOGGLE   Q QUIT"
  VSYNC
LOOP
