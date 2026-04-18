1 REM =========================================================
2 REM gfx_hud_demo — RECT + FILLRECT + DRAWTEXT + DRAWSPRITE
3 REM
4 REM Overlay a HUD on top of a scrolling starfield using only the
5 REM primitive drawing commands (no sprite sheet for the HUD).
6 REM
7 REM Keys: A/D move player, Q quit
8 REM =========================================================
9 SCREEN 1
10 SPRITE LOAD 1, "ship.png"
20 PLX = 144 : PLY = 160 : SC = 0
30 N = 40
40 DIM SX(N-1)
50 DIM SY(N-1)
60 DIM SV(N-1)
70 FOR I = 0 TO N-1
80 SX(I) = INT(RND(1)*320)
90 SY(I) = INT(RND(1)*140)
100 SV(I) = 1 + INT(RND(1)*3)
110 NEXT I
120 REM --- main loop ---
130 IF KEYDOWN(ASC("Q")) THEN END
140 IF KEYDOWN(ASC("A")) THEN PLX = PLX - 3
150 IF KEYDOWN(ASC("D")) THEN PLX = PLX + 3
160 IF PLX < 0 THEN PLX = 0
170 IF PLX > 288 THEN PLX = 288
180 REM erase star area + HUD interior (COLOR 0 FILLRECT clears bits; no CLS flicker)
182 COLOR 0
184 FILLRECT 0, 0 TO 319, 143
186 FILLRECT 1, 145 TO 318, 155
190 REM starfield — 40 pixel-dots via PSET
195 COLOR 1
200 FOR I = 0 TO N-1
210 SX(I) = SX(I) + SV(I)
220 IF SX(I) > 320 THEN SX(I) = 0 : SY(I) = INT(RND(1)*140)
230 PSET SX(I), SY(I)
240 NEXT I
250 REM HUD frame (redrawn each tick since interior was erased)
260 RECT 0, 144 TO 319, 156
270 REM DRAWTEXT at pixel coords; chars 8x8, pen=1 over a clear interior
280 DRAWTEXT 4, 147, "SCORE "
290 DRAWTEXT 56, 147, STR$(SC)
300 DRAWTEXT 160, 147, "A/D MOVE  Q QUIT"
310 REM solid bar showing speed (short FILLRECT in the right margin)
320 FILLRECT 288, 146 TO 288 + (SC / 60) MOD 32, 154
330 DRAWSPRITE 1, PLX, PLY, 100
340 SC = SC + 1
350 VSYNC
360 GOTO 130
