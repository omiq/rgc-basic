' ============================================================
'  RGC-BASIC mouse demo - exercises every mouse API
'   Native: ./basic-gfx examples/gfx_mouse_demo.bas
'   Canvas: load into canvas.html (or web/mouse-demo.html) + Run
'
'  Controls:
'    LEFT button    paint pixels at the cursor
'    RIGHT button   clear the drawing area
'    MIDDLE button  toggle cursor visibility (HIDECURSOR / SHOWCURSOR)
'    LEFT+RIGHT     warp pointer to centre (MOUSESET 160, 100)
'
'  Cursor shape auto-changes by vertical zone:
'    top banner  -> 5 (pointer hand)
'    middle band -> 4 (crosshair)
'    bottom area -> 0 (default)
' ============================================================

SCREEN 1
COLOR 1
BACKGROUND 6
PRINT CHR$(147);

GOSUB DrawBanner
HIDDEN   = 0
WARPSHOW = 0
LASTZONE = -1
KEYBASE  = 56320

DO
  MX = GETMOUSEX()
  MY = GETMOUSEY()

  IF ISMOUSEBUTTONDOWN(0) THEN PSET MX, MY
  IF ISMOUSEBUTTONPRESSED(1) THEN GOSUB ClearArea
  IF ISMOUSEBUTTONPRESSED(2) THEN GOSUB ToggleCursor
  IF ISMOUSEBUTTONDOWN(0) AND ISMOUSEBUTTONDOWN(1) THEN GOSUB WarpCentre

  ZONE = 0
  IF MY < 40 THEN ZONE = 5
  IF MY >= 40 AND MY < 140 THEN ZONE = 4
  IF ZONE <> LASTZONE THEN GOSUB ApplyCursor

  LOCATE 24, 1
  PRINT "X="; MX; " Y="; MY;
  PRINT " L="; ISMOUSEBUTTONDOWN(0);
  PRINT " R="; ISMOUSEBUTTONDOWN(1);
  PRINT " M="; ISMOUSEBUTTONDOWN(2); "    ";

  IF WARPSHOW > 0 THEN GOSUB WarpMarker

  SLEEP 1
LOOP

' ------------------------------------------------------------

WarpMarker:
  PSET MX, MY
  WARPSHOW = WARPSHOW - 1
RETURN

WarpCentre:
  MOUSESET 160, 100
  WARPSHOW = 6
RETURN

ApplyCursor:
  SETMOUSECURSOR ZONE
  LASTZONE = ZONE
RETURN

DrawBanner:
  LOCATE 1, 1
  PRINT "{WHT}RGC-BASIC MOUSE DEMO"
  PRINT "{GRN}LEFT PAINT   RIGHT CLEAR   MID HIDE/SHOW"
  PRINT "{YEL}LEFT+RIGHT WARPS POINTER TO CENTRE"
  PRINT "{CYN}--------------------------------"
RETURN

ClearArea:
  BITMAPCLEAR
  PRINT CHR$(147);
  GOSUB DrawBanner
RETURN

ToggleCursor:
  IF HIDDEN = 0 THEN
    HIDECURSOR
    HIDDEN = 1
  ELSE
    SHOWCURSOR
    HIDDEN = 0
  END IF
RETURN
