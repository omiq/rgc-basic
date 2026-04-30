REM #IF MODERN block contains modern-only code; #IF RETRO contains
REM portable-only fallback. Linter --tier=portable should ONLY validate
REM the RETRO branch and the unconditional code, not the MODERN branch.

#OPTION tier portable

SCREEN 1
SPRITE LOAD 0, "ship.png"

#IF MODERN
SCREEN 4
LOADSCREEN "panorama.png"
COLORRGB 255, 0, 0
FILLCIRCLE 320, 200, 80
#END IF

#IF RETRO
COLOR 7
FILLCIRCLE 160, 100, 30
#END IF

DO
  IF KEYDOWN(81) THEN EXIT
  SPRITE DRAW 0, 100, 100
  VSYNC
LOOP
END
