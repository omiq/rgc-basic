1 REM =========================================================
2 REM gfx_sprite_demo — basic PNG sprite load + move
3 REM Commands shown: LOADSPRITE, DRAWSPRITE, CLS
4 REM (also spellable SPRITE LOAD / SPRITE DRAW once v1.9 lands —
5 REM both tokenise to the same opcode, see docs/tilemap-sheet-plan.md)
6 REM Asset: examples/ship.png (32x32)
7 REM Keys: W A S D move, Q quit
8 REM Run:  ./basic-gfx examples/gfx_sprite_demo.bas
9 REM =========================================================
10 PRINT CHR$(14)
20 PRINT "{CLR}SPRITE DEMO — WASD to move, Q to quit"
30 LOADSPRITE 0,"ship.png"
40 X = 144 : Y = 84
50 S = 4 : REM pixels per step
60 REM ---- main loop ----
70 K$ = UCASE$(INKEY$())
80 IF K$ = "Q" THEN END
90 IF K$ = "A" THEN X = X - S
100 IF K$ = "D" THEN X = X + S
110 IF K$ = "W" THEN Y = Y - S
120 IF K$ = "S" THEN Y = Y + S
130 IF X < 0 THEN X = 0
140 IF X > 288 THEN X = 288
150 IF Y < 0 THEN Y = 0
160 IF Y > 168 THEN Y = 168
170 CLS
180 PRINT "{HOME}X=";X;" Y=";Y;"   "
190 DRAWSPRITE 0,X,Y,100
200 VSYNC
210 GOTO 70
