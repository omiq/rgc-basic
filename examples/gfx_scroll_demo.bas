' ============================================================
'  gfx_scroll_demo - smooth bitmap scroll via IMAGE COPY
'
'  AMOS-style pattern: build an oversized off-screen world
'  bitmap and blit a 320x200 window from it each frame at
'  varying offsets. Wraps horizontally.
'
'  Commands: IMAGE NEW, IMAGE COPY, PSET, CLS
'  Keys: Q quit
' ============================================================

SCREEN 1

' --- 1. Paint a 16x16 tile into the visible bitmap (slot 0) ---
CLS
FOR Y = 0 TO 15 : PSET 0,  Y : PSET 15, Y : NEXT Y
FOR X = 0 TO 15 : PSET X,  0 : PSET X, 15 : NEXT X
PSET 7, 7 : PSET 8, 8 : PSET 7, 8 : PSET 8, 7

' --- 2. Capture it into off-screen surface 1 ------------------
IMAGE NEW 1, 16, 16
IMAGE COPY 0, 0, 0, 16, 16 TO 1, 0, 0

' --- 3. Build a 640x200 world (surface 2) by stamping tiles ---
IMAGE NEW 2, 640, 200
FOR R = 0 TO 12
  FOR C = 0 TO 39
    IMAGE COPY 1, 0, 0, 16, 16 TO 2, C * 16, R * 16
  NEXT C
NEXT R

CLS

' --- 4. Scroll: blit 320x200 window from surface 2 each frame --
XO = 0

DO
  K$ = UCASE$(INKEY$())
  IF K$ = "Q" THEN EXIT

  IMAGE COPY 2, XO, 0, 320, 200 TO 0, 0, 0

  XO = XO + 2
  IF XO >= 320 THEN XO = 0
  VSYNC
LOOP
