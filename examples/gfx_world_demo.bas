1 REM =========================================================
2 REM gfx_world_demo — tilemap world + auto vertical scroll + WASD player
3 REM
4 REM Combines:
5 REM   TILEMAP DRAW to render a 40x40 world of 32x32 tiles
6 REM   Auto vertical scroll — camera advances every frame at VDIR speed
7 REM                          (hit W to scroll up, S to scroll down)
8 REM   Horizontal push scroll — camera only shifts when the player
9 REM                           reaches a 96px viewport margin
10 REM   Keyboard state polled via PEEK(56320+ASC) so A/D + W/S work
11 REM   together, enabling diagonal movement.
12 REM   DRAWSPRITE to draw the player on top (ship.png, z=100)
13 REM
14 REM Assets: tile_sheet.png (64x32, 2 tiles), ship.png (32x32 alpha)
15 REM Keys:   A/D move player, W/S flip vertical scroll direction, Q quit
16 REM =========================================================
20 SPRITE LOAD 0, "tile_sheet.png", 32, 32
30 SPRITE LOAD 1, "ship.png"
40 WW = 40 : WH = 40                     : REM world grid, tiles
50 TW = 32 : TH = 32                     : REM tile size
60 VW = 320 : VH = 200                   : REM viewport
70 DIM WORLD(WW*WH-1)
80 REM deterministic pattern so the scroll effect is visible
90 FOR I = 0 TO WW*WH-1
100 IF (I*17+3) MOD 9 = 0 THEN WORLD(I) = 2 ELSE WORLD(I) = 1
110 NEXT I
120 PX = WW*TW/2 : PY = WH*TH/2          : REM player world-pixel pos
130 CX = PX - VW/2 : CY = PY - VH/2      : REM camera (top-left in world)
140 SPD = 3                              : REM horizontal player speed
150 VDIR = 1                             : REM vertical scroll: +1 down, -1 up
160 EM = 96                              : REM horizontal edge-push margin
170 KB = 56320                           : REM GFX_KEY_BASE for PEEK
180 REM --- main loop ---
190 IF PEEK(KB+81) <> 0 THEN END                      : REM Q
200 IF PEEK(KB+65) <> 0 THEN PX = PX - SPD            : REM A
210 IF PEEK(KB+68) <> 0 THEN PX = PX + SPD            : REM D
220 IF PEEK(KB+87) <> 0 THEN VDIR = -1                : REM W flips scroll up
230 IF PEEK(KB+83) <> 0 THEN VDIR = 1                 : REM S flips scroll down
240 REM vertical: auto-advance camera and player together
250 CY = CY + VDIR
260 PY = PY + VDIR
270 REM bounce at world top/bottom so the scroll never stalls
280 IF CY < 0 THEN CY = 0 : VDIR = 1 : PY = CY + VH/2
290 IF CY > WH*TH-VH THEN CY = WH*TH-VH : VDIR = -1 : PY = CY + VH/2
300 REM horizontal: clamp player to world, push-scroll camera
310 IF PX < 0 THEN PX = 0
320 IF PX > WW*TW-TW THEN PX = WW*TW-TW
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
430 GOTO 190
