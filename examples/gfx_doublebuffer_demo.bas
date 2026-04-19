' ============================================================
'  gfx_doublebuffer_demo - flicker-free bitmap animation
'
'  DOUBLEBUFFER ON tells the renderer to read from a committed
'  back-buffer instead of the live bitmap. BASIC keeps drawing
'  to the same commands (CLS / FILLCIRCLE / DRAWTEXT / ...), but
'  the display only updates when VSYNC promotes the frame.
'
'  Legacy programs that never call VSYNC keep single-buffered
'  behaviour (DOUBLEBUFFER default is OFF) — so existing code
'  is unaffected.
'
'  Keys: SPACE flip double-buffer ON/OFF to compare, Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
DOUBLEBUFFER ON
DB = 1

BX = 160 : BY = 100 : BR = 6
VX = 3   : VY = 2
BOUNCES = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN
    DB = 1 - DB
    IF DB = 1 THEN DOUBLEBUFFER ON ELSE DOUBLEBUFFER OFF
  END IF

  BX = BX + VX
  BY = BY + VY
  IF BX - BR <   8 THEN BX =   8 + BR : VX = -VX : BOUNCES = BOUNCES + 1
  IF BX + BR > 311 THEN BX = 311 - BR : VX = -VX : BOUNCES = BOUNCES + 1
  IF BY - BR <   8 THEN BY =   8 + BR : VY = -VY : BOUNCES = BOUNCES + 1
  IF BY + BR > 175 THEN BY = 175 - BR : VY = -VY : BOUNCES = BOUNCES + 1

  CLS
  RECT 8, 8 TO 311, 175
  FILLCIRCLE BX, BY, BR
  DRAWTEXT 12, 182, "BOUNCES " + STR$(BOUNCES)
  IF DB = 1 THEN
    DRAWTEXT 140, 182, "DBUF ON   SPACE TO FLIP"
  ELSE
    DRAWTEXT 140, 182, "DBUF OFF  SPACE TO FLIP"
  END IF

  VSYNC
LOOP
