1 REM =========================================================
2 REM gfx_stamp_demo — 50 moving particles + WASD player
3 REM
4 REM Demonstrates SPRITE STAMP — unlike DRAWSPRITE (one persistent
5 REM position per slot) STAMP appends to the per-frame cell list, so
6 REM N calls with the same slot draw N distinct copies.
7 REM
8 REM Assets: tile.png (32x32 particle), ship.png (32x32 alpha player)
9 REM Keys:   WASD move player, Q quit
10 REM =========================================================
20 SPRITE LOAD 0, "tile.png"
30 SPRITE LOAD 1, "ship.png"
40 N = 50
50 DIM SX(N-1)
60 DIM SY(N-1)
70 DIM SV(N-1)
80 FOR I = 0 TO N-1
90 SX(I) = INT(RND(1)*320)
100 SY(I) = INT(RND(1)*180)
110 SV(I) = 1 + INT(RND(1)*3)
120 NEXT I
130 PLX = 144 : PLY = 84
140 REM --- main loop ---
150 IF KEYDOWN(ASC("Q")) THEN END
160 IF KEYDOWN(ASC("A")) THEN PLX = PLX - 2
170 IF KEYDOWN(ASC("D")) THEN PLX = PLX + 2
180 IF KEYDOWN(ASC("W")) THEN PLY = PLY - 2
190 IF KEYDOWN(ASC("S")) THEN PLY = PLY + 2
200 IF PLX < 0 THEN PLX = 0
210 IF PLX > 288 THEN PLX = 288
220 IF PLY < 0 THEN PLY = 0
230 IF PLY > 168 THEN PLY = 168
240 CLS
250 REM advance + stamp each particle (50 SPRITE STAMPs per frame,
260 REM all slot 0, all distinct positions on screen)
270 FOR I = 0 TO N-1
280 SX(I) = SX(I) + SV(I)
290 IF SX(I) > 320 THEN SX(I) = -32 : SY(I) = INT(RND(1)*180)
300 SPRITE STAMP 0, SX(I), SY(I), 0, 10
310 NEXT I
320 REM player (persistent position — only one instance)
330 DRAWSPRITE 1, PLX, PLY, 100
340 SLEEP 1
350 GOTO 150
