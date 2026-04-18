1 REM =========================================================
2 REM gfx_tilemap_demo — batched tile grid via TILEMAP DRAW
3 REM
4 REM Replaces the 70-call loop in gfx_tile_demo.bas with ONE
5 REM interpreter dispatch. Runtime iterates the map array in C.
6 REM
7 REM Asset: tile_sheet.png (64x32 = 2 cells of 32x32:
8 REM   index 1 = healthy, index 2 = damaged).
9 REM
10 REM Layout: top 3 text rows + 5 tile rows (160px) + bottom
11 REM text row leave room for status without tiles covering it.
12 REM
13 REM Keys: SPACE damage random cell, R reset, Q quit
14 REM =========================================================
20 PRINT CHR$(14)
30 SPRITE LOAD 0, "tile_sheet.png", 32, 32
40 COLS = 10 : ROWS = 5
50 TY = 24
60 DIM MAP(COLS*ROWS-1)
70 FOR I = 0 TO COLS*ROWS-1 : MAP(I) = 1 : NEXT I
80 REM ---- main loop ----
90 K$ = UCASE$(INKEY$())
100 IF K$ = "Q" THEN END
110 IF K$ = "R" THEN FOR I = 0 TO COLS*ROWS-1 : MAP(I) = 1 : NEXT I
120 IF K$ = " " THEN MAP(INT(RND(1)*COLS*ROWS)) = 2
130 CLS
140 PRINT "{HOME}TILEMAP DEMO - SHEET HAS ";TILE COUNT(0);" TILES"
150 TILEMAP DRAW 0, 0, TY, COLS, ROWS, MAP()
160 LOCATE 1, 24
170 PRINT "SPACE = damage  R = reset  Q = quit";
180 VSYNC
190 GOTO 90
