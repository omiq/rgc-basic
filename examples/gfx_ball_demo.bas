' ============================================================
'  gfx_ball_demo - bouncing ball using only bitmap primitives
'
'  Demonstrates FILLCIRCLE (ball), RECT (playfield frame),
'  DRAWTEXT (HUD), KEYDOWN (pause + quit).
'
'  Partial-erase pattern: no full-screen CLS inside the loop.
'  Bitmap plane is not double-buffered (see to-do.md 2026-04-19),
'  so clearing + redrawing the whole frame flickers. Erase only
'  what moved (old ball bbox, HUD text band) and redraw the
'  static parts (playfield frame).
'
'  Keys: SPACE pause/resume, Q quit
' ============================================================

SCREEN 1
BACKGROUND 0

BX = 160 : BY = 100 : BR = 6
VX = 3   : VY = 2
OBX = BX : OBY = BY
PAUSED  = 0
BOUNCES = 0

' Draw playfield frame once so it's on screen before the loop
COLOR 1
RECT 8, 8 TO 311, 175

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN PAUSED = 1 - PAUSED

  IF PAUSED = 0 THEN
    OBX = BX : OBY = BY
    BX = BX + VX
    BY = BY + VY
    IF BX - BR <   8 THEN BX =   8 + BR : VX = -VX : BOUNCES = BOUNCES + 1
    IF BX + BR > 311 THEN BX = 311 - BR : VX = -VX : BOUNCES = BOUNCES + 1
    IF BY - BR <   8 THEN BY =   8 + BR : VY = -VY : BOUNCES = BOUNCES + 1
    IF BY + BR > 175 THEN BY = 175 - BR : VY = -VY : BOUNCES = BOUNCES + 1
  END IF

  ' Erase old ball + HUD band
  COLOR 0
  FILLCIRCLE OBX, OBY, BR + 1
  FILLRECT 0, 177 TO 319, 199

  ' Redraw frame (fast; FILLCIRCLE erase above may have clipped its edge)
  COLOR 1
  RECT 8, 8 TO 311, 175

  ' Draw new ball
  FILLCIRCLE BX, BY, BR

  ' HUD
  DRAWTEXT 12, 182, "BOUNCES "
  DRAWTEXT 80, 182, STR$(BOUNCES)
  IF PAUSED = 1 THEN DRAWTEXT 200, 182, "PAUSED"
  IF PAUSED = 0 THEN DRAWTEXT 120, 182, "Q QUIT  SPACE PAUSE"

  VSYNC
LOOP
