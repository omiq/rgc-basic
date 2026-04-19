' ============================================================
'  gfx_showcase - tour of every bitmap primitive in RGC BASIC
'
'  Static scene drawn once; only the spinner animates. A small
'  erase-box around the spinner each tick avoids a full-screen CLS
'  (which would flicker every frame).
'
'  Keys: Q quit
' ============================================================

SCREEN 1

' 6-point convex polygon vertices (stars-ish silhouette)
DIM PX(5)
DIM PY(5)
PX(0) = 60 : PY(0) = 172
PX(1) = 78 : PY(1) = 160
PX(2) = 96 : PY(2) = 172
PX(3) = 90 : PY(3) = 192
PX(4) = 66 : PY(4) = 192
PX(5) = 56 : PY(5) = 182

' --- one-off static draws ------------------------------------
' row 1: outline primitives
RECT     8, 16 TO 56, 48
CIRCLE   84, 32, 16
ELLIPSE 134, 32, 22, 12
TRIANGLE 168, 48, 196, 16, 224, 48
LINE     240, 16 TO 280, 48
LINE     280, 16 TO 240, 48
FOR I = 240 TO 280 STEP 4 : PSET I, 32 : NEXT I

DRAWTEXT   8, 4, "RECT"
DRAWTEXT  68, 4, "CIRCLE"
DRAWTEXT 120, 4, "ELLIPSE"
DRAWTEXT 176, 4, "TRI"
DRAWTEXT 232, 4, "LINE+PSET"

' row 2: fills
FILLRECT      8,  72 TO 56, 104
FILLCIRCLE   84,  88, 16
FILLELLIPSE 134,  88, 22, 12
FILLTRIANGLE 168, 104, 196, 72, 224, 104
POLYGON      6, PX(), PY()

DRAWTEXT   8, 60, "RECT"
DRAWTEXT  68, 60, "CIRC"
DRAWTEXT 120, 60, "ELL"
DRAWTEXT 168, 60, "TRI"
DRAWTEXT 232, 60, "SPIN"

' row 3: POLYGON + FLOODFILL
DRAWTEXT  56, 148, "POLYGON"
RECT 140, 156 TO 200, 196
FLOODFILL 170, 176
DRAWTEXT 208, 170, "FLOODFILL"

' frame + title
RECT 0, 0 TO 319, 199
DRAWTEXT 56, 120, "RGC-BASIC GRAPHICS TOUR"
DRAWTEXT 96, 132, "PRESS Q TO QUIT"

' Spinner geometry
CX = 280 : CY = 88
EX1 = CX - 15 : EY1 = CY - 15
EX2 = CX + 15 : EY2 = CY + 15
T = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Erase just the spinner box - no full-screen CLS
  COLOR 0
  FILLRECT EX1, EY1 TO EX2, EY2

  COLOR 1
  CIRCLE CX, CY, 14
  PSET CX, CY
  RX = CX + INT(12 * COS(T * 3.14159 / 180))
  RY = CY + INT(12 * SIN(T * 3.14159 / 180))
  LINE CX, CY TO RX, RY

  T = T + 6
  IF T >= 360 THEN T = 0
  VSYNC
LOOP
