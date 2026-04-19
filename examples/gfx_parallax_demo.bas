' ============================================================
'  gfx_parallax_demo - 3-band parallax scroll via IMAGE COPY
'
'  Three 320-wide bands scroll at different speeds:
'    sky    (y   0..59)   1 px/tick (slowest/farthest)
'    mid    (y  60..139)  2 px/tick
'    ground (y 140..199)  4 px/tick (fastest/closest)
'
'  Each band lives in its own off-screen surface at twice the
'  viewport width so IMAGE COPY with a wrapping offset blits a
'  seamless loop onto the visible bitmap.
'
'  Keys: Q quit
' ============================================================

SCREEN 1                              ' hi-res bitmap mode

' --- Build each band in its own surface ----------------------
IMAGE NEW 1, 640, 60                  ' sky
IMAGE NEW 2, 640, 80                  ' mid
IMAGE NEW 3, 640, 60                  ' ground

' Paint sky markers -> capture x2 into surface 1
CLS
FOR X = 0 TO 319 STEP 64
  FOR Y = 0 TO 59
    PSET X, Y : PSET X + 1, Y
  NEXT Y
NEXT X
FOR I = 0 TO 1
  IMAGE COPY 0, 0, 0, 320, 60 TO 1, I * 320, 0
NEXT I

' Paint mid markers -> surface 2
CLS
FOR X = 0 TO 319 STEP 24
  FOR Y = 0 TO 79
    PSET X, Y
  NEXT Y
NEXT X
FOR I = 0 TO 1
  IMAGE COPY 0, 0, 0, 320, 80 TO 2, I * 320, 0
NEXT I

' Paint ground markers -> surface 3
CLS
FOR X = 0 TO 319 STEP 8
  FOR Y = 0 TO 59
    PSET X, Y
  NEXT Y
NEXT X
FOR I = 0 TO 1
  IMAGE COPY 0, 0, 0, 320, 60 TO 3, I * 320, 0
NEXT I

CLS

' --- Main loop ------------------------------------------------
XS = 0 : XM = 0 : XG = 0

DO
  K$ = UCASE$(INKEY$())
  IF K$ = "Q" THEN EXIT

  IMAGE COPY 1, XS, 0, 320, 60 TO 0, 0,   0
  IMAGE COPY 2, XM, 0, 320, 80 TO 0, 0,  60
  IMAGE COPY 3, XG, 0, 320, 60 TO 0, 0, 140

  XS = XS + 1 : IF XS >= 320 THEN XS = 0
  XM = XM + 2 : IF XM >= 320 THEN XM = 0
  XG = XG + 4 : IF XG >= 320 THEN XG = 0

  VSYNC
LOOP
