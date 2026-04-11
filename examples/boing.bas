#OPTION petscii

REM ================================
REM   BOING!
REM   Amiga Boing Ball Tribute
REM   for RGC-BASIC
REM ================================
REM
REM Uses SCREEN 1 bitmap for the grid
REM and a PNG sprite sheet for the ball.
REM
REM Requires: boing_sheet.png (768x64
REM sprite sheet, 12 frames of 64x64)

REM Switch to 320x200 bitmap mode
SCREEN 1
COLOR 1
BACKGROUND 6

REM Load the ball sprite sheet
REM 12 frames, each 64x64 pixels
LOADSPRITE 1, "boing_sheet.png", 64, 64
SPRITEVISIBLE 1, 1
REM Frame count from loaded sheet (0 if PNG missing or not a tile grid — use 12 as documented)
NT = SPRITETILES(1)
IF NT < 1 THEN NT = 12

REM Draw the grid background
GOSUB DrawGrid

REM Ball position, velocity, sprite frame index (BF — avoid name FRAME; clashes with SPRITEFRAME in some editors)
REM One line keeps numbered-line IDEs from inserting an unnumbered "FRAME = 1" (that breaks parsing).
BX = 40 : BY = 10 : VX = 2 : VY = 2 : BF = 1

REM ~10 animation fps: 60 jiffies/s / 10 = 6 jiffies per sprite frame (TI = wall clock in canvas/basic-gfx)
JIFFIES_PER_FRAME = 6
LAST = TI

REM === Main Loop ===
REM Use SPRITEFRAME + DRAWSPRITE (tile crop is applied inside DRAWSPRITE for sheets).
REM DRAWSPRITETILE would error if the PNG failed to load or tile grid could not be built.
DO
  SPRITEFRAME 1, BF
  DRAWSPRITE 1, BX, BY

  SLEEP 1

  REM Update position every frame (movement speed unchanged)
  BX = BX + VX
  BY = BY + VY

  REM Advance rotation on TI — independent of movement
  IF TI - LAST >= JIFFIES_PER_FRAME THEN
    LAST = TI
    BF = BF + 1
    IF BF > NT THEN BF = 1
  END IF

  REM Bounce off edges
  IF BX < 0 OR BX > 256 THEN VX = -VX
  IF BY < 0 OR BY > 130 THEN VY = -VY

LOOP

REM ----- Draw grid with LINE -----
DrawGrid:
  REM Vertical lines
  FOR X = 20 TO 300 STEP 20
    LINE X, 0 TO X, 199
  NEXT X

  REM Horizontal lines
  FOR Y = 14 TO 199 STEP 14
    LINE 0, Y TO 319, Y
  NEXT Y
RETURN
