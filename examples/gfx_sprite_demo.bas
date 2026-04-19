' ============================================================
'  gfx_sprite_demo - basic PNG sprite load + move
'  Commands: LOADSPRITE (aka SPRITE LOAD), DRAWSPRITE, CLS
'  Asset: examples/ship.png (32x32)
'  Run:  ./basic-gfx examples/gfx_sprite_demo.bas
'  Keys: W A S D move, Q quit
' ============================================================

PRINT CHR$(14)
PRINT "{CLR}SPRITE DEMO - WASD to move, Q to quit"

LOADSPRITE 0, "ship.png"

X = 144 : Y = 84
S = 4                        ' pixels per step

DO
  K$ = UCASE$(INKEY$())
  IF K$ = "Q" THEN EXIT
  IF K$ = "A" THEN X = X - S
  IF K$ = "D" THEN X = X + S
  IF K$ = "W" THEN Y = Y - S
  IF K$ = "S" THEN Y = Y + S
  IF X < 0   THEN X = 0
  IF X > 288 THEN X = 288
  IF Y < 0   THEN Y = 0
  IF Y > 168 THEN Y = 168

  
  PRINT "{HOME}X="; X; " Y="; Y; "   "
  DRAWSPRITE 0, X, Y, 100

LOOP
