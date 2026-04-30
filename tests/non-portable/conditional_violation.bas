REM Should fail: SCREEN 4 outside any #IF MODERN guard. Linter must
REM still flag it because no guard scopes the modern-only call.

#OPTION tier portable

SCREEN 1
SPRITE LOAD 0, "ship.png"

#IF RETRO
COLOR 7
FILLCIRCLE 160, 100, 30
#END IF

SCREEN 4

END
