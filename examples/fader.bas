#OPTION petscii

REM ================================
REM FADING IN AND OUT
REM ================================


REM Switch to 320x200 bitmap mode
SCREEN 1
COLOR 1
BACKGROUND 6

REM Load the ball sprite sheet
REM 12 frames, each 64x64 pixels
LOADSPRITE 1, "boing_sheet.png", 64, 64
LOADSPRITE 2, "boing_shadow.png"

REM Set shadow colour tint and opacity
SPRITEMODULATE 2, 150, 255, 255, 255
SPRITEVISIBLE 1, 1
SPRITEVISIBLE 2, 1


REM Draw the grid background
GOSUB DrawGrid

REM Ball position, velocity, sprite frame index (BF — avoid name FRAME; clashes with SPRITEFRAME in some editors)
REM One line keeps numbered-line IDEs from inserting an unnumbered "FRAME = 1" (that breaks parsing).
BX = 40 : BY = 10 : VX = 2 : VY = 2 : BF = 1

REM ~10 animation fps: 60 jiffies/s / 10 = 6 jiffies per sprite frame (TI = wall clock in canvas/basic-gfx)
JIFFIES_PER_FRAME = 6
LAST = TI
A=255
F=-1
REM === Main Loop ===
DO

  REM Draw shadow at current position 
  DRAWSPRITE 2, BX+8, BY+8, 1
  REM Draw ball at current position and rotation frame
  DRAWSPRITETILE 1, BX, BY, BF, 2

 

  FOR A=0 TO 255 STEP 10
  SPRITEMODULATE 1, A, 0, 0, A
  SLEEP 1
  NEXT A

  FOR A=0 TO 255 STEP 10
  SPRITEMODULATE 1, 255, A, 0, 255
  SLEEP 1
  NEXT A

  FOR A=0 TO 255 STEP 10
  SPRITEMODULATE 1, 255, 255, A, 255
  SLEEP 1
  NEXT A

  FOR A=255 TO 0 STEP -1
  SPRITEMODULATE 1, A, A, A, A
  SLEEP 1
  NEXT A



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