REM chicks.bas -- 256 chicks using SPRITECOPY
REM Load chick.png once, clone into 255 more slots, then scatter them randomly.
REM SPRITECOPY avoids 255 redundant file loads.

LOADSPRITE 0, "chick.png"
FOR S = 1 TO 255
  SPRITECOPY 0, S
NEXT S

REM Initial scatter
FOR S = 0 TO 255
  DRAWSPRITE S, (RND(1)*320)-32, (RND(1)*200)-32
NEXT S

REM Keep bouncing them around
DO
  FOR S = 0 TO 255
    DRAWSPRITE S, (RND(1)*320)-32, (RND(1)*200)-32
  NEXT S
LOOP
