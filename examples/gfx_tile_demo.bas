1 REM =========================================================
2 REM gfx_tile_demo — stamp two tile types into a grid by hand
3 REM Commands: LOADSPRITE, DRAWSPRITE (loop stamps each cell)
4 REM Assets: tile.png (healthy), tile-damaged.png (both 32x32)
5 REM This is the "slow path" — one interpreter call per cell.
6 REM A 10x7 grid = 70 DRAWSPRITE calls per paint.
7 REM See spec-preview/gfx_tilemap_demo.bas for the batched TILEMAP
8 REM DRAW version that does this in one call.
9 REM Keys: SPACE = damage random cell, R = reset, Q = quit
10 REM =========================================================
20 PRINT CHR$(14)
30 LOADSPRITE 0,"tile.png"
40 LOADSPRITE 1,"tile-damaged.png"
50 CW = 32 : CH = 32
60 COLS = 10 : ROWS = 6
70 DIM G(COLS*ROWS-1)
80 FOR I = 0 TO COLS*ROWS-1 : G(I) = 0 : NEXT I
90 GOSUB 500 : REM draw full grid
100 PRINT "{HOME}TILE DEMO — SPACE damage, R reset, Q quit"
110 REM ---- main loop ----
120 K$ = UCASE$(INKEY$())
130 IF K$ = "Q" THEN END
140 IF K$ = "R" THEN FOR I = 0 TO COLS*ROWS-1 : G(I) = 0 : NEXT I : GOSUB 500 : GOTO 120
150 IF K$ = " " THEN GOSUB 600
160 SLEEP 1
170 GOTO 120
500 REM ---- draw full grid ----
510 FOR R = 0 TO ROWS-1
520 FOR C = 0 TO COLS-1
530 X = C*CW : Y = R*CH
540 IF G(R*COLS+C) = 0 THEN DRAWSPRITE 0,X,Y,10
550 IF G(R*COLS+C) = 1 THEN DRAWSPRITE 1,X,Y,10
560 NEXT C
570 NEXT R
580 RETURN
600 REM ---- damage a random healthy tile ----
610 IDX = INT(RND(1)*COLS*ROWS)
620 IF G(IDX) = 1 THEN RETURN
630 G(IDX) = 1
640 C = IDX - INT(IDX/COLS)*COLS
650 R = INT(IDX/COLS)
660 DRAWSPRITE 1,C*CW,R*CH,10
670 RETURN
