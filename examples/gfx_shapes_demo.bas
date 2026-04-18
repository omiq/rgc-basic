1 REM =========================================================
2 REM gfx_shapes_demo — tour of every bitmap primitive
3 REM
4 REM PSET, LINE, RECT, FILLRECT, CIRCLE, FILLCIRCLE, ELLIPSE,
5 REM FILLELLIPSE, TRIANGLE, FILLTRIANGLE, DRAWTEXT — all in one
6 REM 320x200 frame. Shapes static; draw once, poll Q to quit.
7 REM
8 REM Keys: Q quit
9 REM =========================================================
10 SCREEN 1
20 REM --- row 1: outlines ---
30 RECT     8, 16 TO 56, 48
40 CIRCLE   88, 32, 16
50 ELLIPSE  136, 32, 24, 12
60 TRIANGLE 168, 48, 196, 16, 224, 48
70 LINE     240, 16 TO 280, 48
80 LINE     280, 16 TO 240, 48
90 FOR I = 240 TO 280 STEP 4 : PSET I, 32 : NEXT I
100 REM --- row 2: fills ---
110 FILLRECT     8, 72 TO 56, 104
120 FILLCIRCLE   88, 88, 16
130 FILLELLIPSE  136, 88, 24, 12
140 FILLTRIANGLE 168, 104, 196, 72, 224, 104
150 REM --- row 3: text with pixel placement ---
160 DRAWTEXT 8, 128, "PSET  LINE"
170 DRAWTEXT 8, 140, "RECT  FILLRECT"
180 DRAWTEXT 8, 152, "CIRCLE FILLCIRCLE"
190 DRAWTEXT 8, 164, "ELLIPSE FILLELLIPSE"
200 DRAWTEXT 8, 176, "TRIANGLE FILLTRIANGLE"
210 DRAWTEXT 8, 188, "DRAWTEXT  Q quit"
220 REM frame
230 RECT 0, 0 TO 319, 199
240 REM poll-only loop: shapes stay rendered, just wait for Q
250 IF KEYDOWN(ASC("Q")) THEN END
260 VSYNC
270 GOTO 250
