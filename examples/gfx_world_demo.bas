1 REM =========================================================
2 REM gfx_world_demo — tilemap world + mixed scroll modes + WASD player
3 REM
4 REM Combines:
5 REM   TILEMAP DRAW to render a 40x40 world of 32x32 tiles
6 REM   Vertical scrolling   — camera smoothly centres on player
7 REM   Horizontal scrolling — push style (camera only moves when
8 REM                          player reaches a 96px viewport margin)
9 REM   DRAWSPRITE to draw the player on top (ship.png, z=100)
10 REM
11 REM Assets: tile_sheet.png (64x32, 2 tiles), ship.png (32x32 alpha)
12 REM Keys:   WASD move, Q quit
13 REM =========================================================
20 SPRITE LOAD 0, "tile_sheet.png", 32, 32
30 SPRITE LOAD 1, "ship.png"
40 WW = 40 : WH = 40                     : REM world grid, tiles
50 TW = 32 : TH = 32                     : REM tile size
60 VW = 320 : VH = 200                   : REM viewport
70 DIM WORLD(WW*WH-1)
80 REM deterministic pattern so the scroll effect is visible
90 FOR I = 0 TO WW*WH-1
95 R = (I*17+3) MOD 9
100 WORLD(I) = 1
105 IF R = 0 THEN WORLD(I) = 2
110 NEXT I
120 PX = WW*TW/2 : PY = WH*TH/2          : REM player world-pixel pos
130 CX = PX - VW/2 : CY = PY - VH/2      : REM camera (top-left in world)
140 SPD = 3
150 EM = 96                              : REM horizontal edge-push margin
160 REM --- main loop ---
170 K$ = UCASE$(INKEY$())
180 IF K$ = "Q" THEN END
190 IF K$ = "A" THEN PX = PX - SPD
200 IF K$ = "D" THEN PX = PX + SPD
210 IF K$ = "W" THEN PY = PY - SPD
220 IF K$ = "S" THEN PY = PY + SPD
230 REM clamp player to world bounds
240 IF PX < 0 THEN PX = 0
250 IF PX > WW*TW-TW THEN PX = WW*TW-TW
260 IF PY < 0 THEN PY = 0
270 IF PY > WH*TH-TH THEN PY = WH*TH-TH
280 REM vertical: smooth centre follow
290 CY = PY - VH/2 + TH/2
300 IF CY < 0 THEN CY = 0
310 IF CY > WH*TH-VH THEN CY = WH*TH-VH
320 REM horizontal: push scroll — camera moves only when player hits margin
330 SCRX = PX - CX
340 IF SCRX < EM THEN CX = PX - EM
350 IF SCRX > VW-EM-TW THEN CX = PX - (VW-EM-TW)
360 IF CX < 0 THEN CX = 0
370 IF CX > WW*TW-VW THEN CX = WW*TW-VW
380 REM --- render ---
390 CLS
400 TILEMAP DRAW 0, -CX, -CY, WW, WH, WORLD()
410 DRAWSPRITE 1, PX-CX, PY-CY, 100
420 SLEEP 1
430 GOTO 170
