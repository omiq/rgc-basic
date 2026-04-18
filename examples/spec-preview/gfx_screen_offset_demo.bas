1 REM =========================================================
2 REM gfx_screen_offset_demo — smooth scroll via SCREEN OFFSET
3 REM STATUS: spec preview, requires rgc-basic v1.9+
4 REM
5 REM Build a world bitmap larger than the 320x200 viewport,
6 REM stamp terrain into it once, then slide the viewport with
7 REM SCREEN OFFSET each frame. No per-frame tile redraw.
8 REM
9 REM Uses blitter-spec IMAGE NEW / IMAGE COPY to build the world
10 REM surface; SCREEN OFFSET to scroll.
11 REM
12 REM Keys: A/D pan left/right, W/S pan up/down, Q quit
13 REM =========================================================
20 PRINT CHR$(14)
30 REM world = 640x400 bitmap (double viewport each axis, wraps)
40 IMAGE NEW 1, 640, 400
50 SPRITE LOAD 0, "tile_sheet.png", 32, 32
60 REM stamp an 20x13 tile grid into surface 1 once
70 COLS = 20 : ROWS = 13
80 DIM MAP(COLS*ROWS-1)
90 FOR I = 0 TO COLS*ROWS-1 : MAP(I) = 1+(I AND 1) : NEXT I
100 REM draw the map into surface 1 (TILEMAP DRAW's first arg is
105 REM the sheet slot; v2 will add a dest-surface arg; meanwhile
110 REM assume current draw target is set to surface 1)
120 TILEMAP DRAW 0, 0, 0, COLS, ROWS, MAP()
130 REM ---- main loop ----
140 XO = 0 : YO = 0
150 K$ = UCASE$(INKEY$())
160 IF K$ = "Q" THEN END
170 IF K$ = "A" THEN XO = XO - 4
180 IF K$ = "D" THEN XO = XO + 4
190 IF K$ = "W" THEN YO = YO - 4
200 IF K$ = "S" THEN YO = YO + 4
210 IF XO < 0 THEN XO = 0
220 IF XO > 320 THEN XO = 320
230 IF YO < 0 THEN YO = 0
240 IF YO > 200 THEN YO = 200
250 REM slide viewport into world surface — no blit, no redraw
260 SCREEN OFFSET 1, XO, YO
270 PRINT "{HOME}OFFSET=";XO;",";YO;"   "
280 SLEEP 1
290 GOTO 150
