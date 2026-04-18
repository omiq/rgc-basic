1 REM =========================================================
2 REM gfx_showcase — tour of every bitmap primitive in RGC BASIC
3 REM
4 REM One frame, 320x200. Animates a small spinner and a ball so the
5 REM render pipeline is visible: CLS on the build buffer, per-frame
6 REM redraw of all shapes, VSYNC for atomic commit.
7 REM
8 REM Keys: Q quit
9 REM =========================================================
10 SCREEN 1
20 REM pre-dim polygon vertex arrays
30 DIM PX(5)
40 DIM PY(5)
50 REM star-ish 6-point convex polygon
60 PX(0)=60  : PY(0)=172
70 PX(1)=78  : PY(1)=160
80 PX(2)=96  : PY(2)=172
90 PX(3)=90  : PY(3)=192
100 PX(4)=66 : PY(4)=192
110 PX(5)=56 : PY(5)=182
120 T = 0
130 REM --- main loop ---
140 IF KEYDOWN(ASC("Q")) THEN END
150 CLS
160 REM --- row 1: outline primitives ---
170 RECT     8, 16 TO 56, 48
180 CIRCLE   84, 32, 16
190 ELLIPSE  134, 32, 22, 12
200 TRIANGLE 168, 48, 196, 16, 224, 48
210 LINE     240, 16 TO 280, 48
220 LINE     280, 16 TO 240, 48
230 FOR I = 240 TO 280 STEP 4 : PSET I, 32 : NEXT I
240 REM labels above each outline
250 DRAWTEXT   8, 4, "RECT"
260 DRAWTEXT  72, 4, "CIRCLE"
270 DRAWTEXT 116, 4, "ELLIPSE"
280 DRAWTEXT 168, 4, "TRI"
290 DRAWTEXT 240, 4, "LINE+PSET"
300 REM --- row 2: fills ---
310 FILLRECT      8,  72 TO 56, 104
320 FILLCIRCLE   84,  88, 16
330 FILLELLIPSE 134,  88, 22, 12
340 FILLTRIANGLE 168, 104, 196, 72, 224, 104
350 POLYGON     6, PX(), PY()
360 REM --- animated spinner (rotating line in a filled circle) ---
370 CX = 280 : CY = 88
380 CIRCLE CX, CY, 14
385 PSET CX, CY
390 RX = CX + INT(12 * COS(T * 3.14159 / 180))
400 RY = CY + INT(12 * SIN(T * 3.14159 / 180))
410 LINE CX, CY TO RX, RY
420 DRAWTEXT  8,  60, "FILLRECT"
430 DRAWTEXT 64,  60, "FILLCIRCLE"
440 DRAWTEXT 132, 60, "FILLELL"
450 DRAWTEXT 168, 60, "FILLTRI"
460 DRAWTEXT 232, 60, "SPIN"
470 REM --- row 3: POLYGON label + FLOODFILL region ---
480 DRAWTEXT 60, 160, "POLYGON"
490 REM outline a closed box then FLOODFILL its interior
500 RECT 140, 156 TO 200, 196
510 FLOODFILL 170, 176
520 DRAWTEXT 208, 170, "FLOODFILL"
530 REM --- frame + title ---
540 RECT 0, 0 TO 319, 199
550 DRAWTEXT 90, 120, "RGC-BASIC GRAPHICS TOUR"
560 DRAWTEXT 96, 132, "PRESS Q TO QUIT"
570 T = T + 6
580 IF T >= 360 THEN T = 0
590 VSYNC
600 GOTO 140
