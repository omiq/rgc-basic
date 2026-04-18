1 REM =========================================================
2 REM gfx_sheet_info_demo — query loaded sheet metadata
3 REM
4 REM Six accessors, all reading the same underlying sheet record.
6 REM Pick the one whose intent matches your code — SPRITE FRAMES
7 REM for animators, TILE COUNT for tilemap authors, SHEET * for
8 REM grid geometry.
9 REM =========================================================
10 PRINT CHR$(14)
20 SPRITE LOAD 0, "ship.png", 32, 32
30 SPRITE LOAD 1, "tile_sheet.png", 32, 32
40 PRINT "{CLR}SHEET METADATA"
50 PRINT "==============="
60 PRINT
70 PRINT "SLOT 0 (ship.png):"
80 PRINT "  SPRITE FRAMES = ";SPRITE FRAMES(0)
90 PRINT "  TILE COUNT    = ";TILE COUNT(0);"  (same number, tile intent)"
100 PRINT "  SHEET COLS    = ";SHEET COLS(0)
110 PRINT "  SHEET ROWS    = ";SHEET ROWS(0)
120 PRINT "  SHEET WIDTH   = ";SHEET WIDTH(0);" px per cell"
130 PRINT "  SHEET HEIGHT  = ";SHEET HEIGHT(0);" px per cell"
140 PRINT
150 PRINT "SLOT 1 (tile_sheet.png):"
160 PRINT "  SPRITE FRAMES = ";SPRITE FRAMES(1)
170 PRINT "  TILE COUNT    = ";TILE COUNT(1)
180 PRINT "  SHEET COLS    = ";SHEET COLS(1)
190 PRINT "  SHEET ROWS    = ";SHEET ROWS(1)
200 PRINT "  SHEET WIDTH   = ";SHEET WIDTH(1);" px per cell"
210 PRINT "  SHEET HEIGHT  = ";SHEET HEIGHT(1);" px per cell"
220 PRINT
230 PRINT "PRESS ANY KEY"
240 K$ = INKEY$() : IF K$ = "" THEN SLEEP 1 : GOTO 240
250 END
