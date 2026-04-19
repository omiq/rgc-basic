' ============================================================
'  gfx_shapes_demo - tour of every bitmap primitive
'
'  PSET, LINE, RECT, FILLRECT, CIRCLE, FILLCIRCLE, ELLIPSE,
'  FILLELLIPSE, TRIANGLE, FILLTRIANGLE, DRAWTEXT - all in one
'  320x200 frame. Drawn once; the main loop just polls for Q.
'
'  Keys: Q quit
' ============================================================

SCREEN 1

' --- row 1: outlines -----------------------------------------
RECT     8, 16 TO 56, 48
CIRCLE   88, 32, 16
ELLIPSE 136, 32, 24, 12
TRIANGLE 168, 48, 196, 16, 224, 48
LINE     240, 16 TO 280, 48
LINE     280, 16 TO 240, 48
FOR I = 240 TO 280 STEP 4 : PSET I, 32 : NEXT I

' --- row 2: fills --------------------------------------------
FILLRECT      8, 72 TO 56, 104
FILLCIRCLE   88, 88, 16
FILLELLIPSE 136, 88, 24, 12
FILLTRIANGLE 168, 104, 196, 72, 224, 104

' --- row 3: text via pixel placement -------------------------
DRAWTEXT 8, 128, "PSET  LINE"
DRAWTEXT 8, 140, "RECT  FILLRECT"
DRAWTEXT 8, 152, "CIRCLE FILLCIRCLE"
DRAWTEXT 8, 164, "ELLIPSE FILLELLIPSE"
DRAWTEXT 8, 176, "TRIANGLE FILLTRIANGLE"
DRAWTEXT 8, 188, "DRAWTEXT  Q quit"

' --- frame ---------------------------------------------------
RECT 0, 0 TO 319, 199

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  VSYNC
LOOP
