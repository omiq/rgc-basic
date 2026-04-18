1 REM =========================================================
2 REM gfx_showcase — tour of every bitmap primitive in RGC BASIC
3 REM
4 REM Static scene drawn once; only the spinner rotates. Erase a
5 REM small box around the spinner each tick to avoid whole-screen
6 REM CLS flicker.
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
130 REM --- one-off static draws ---
140 REM row 1: outline primitives
150 RECT     8, 16 TO 56, 48
160 CIRCLE   84, 32, 16
170 ELLIPSE  134, 32, 22, 12
180 TRIANGLE 168, 48, 196, 16, 224, 48
190 LINE     240, 16 TO 280, 48
200 LINE     280, 16 TO 240, 48
210 FOR I = 240 TO 280 STEP 4 : PSET I, 32 : NEXT I
220 REM labels above each outline
230 DRAWTEXT   8, 4, "RECT"
240 DRAWTEXT  68, 4, "CIRCLE"
250 DRAWTEXT 120, 4, "ELLIPSE"
260 DRAWTEXT 176, 4, "TRI"
270 DRAWTEXT 232, 4, "LINE+PSET"
280 REM row 2: fills
290 FILLRECT      8,  72 TO 56, 104
300 FILLCIRCLE   84,  88, 16
310 FILLELLIPSE 134,  88, 22, 12
320 FILLTRIANGLE 168, 104, 196, 72, 224, 104
330 POLYGON     6, PX(), PY()
340 REM row 2 labels (between rows, non-overlapping)
350 DRAWTEXT   8, 60, "RECT"
360 DRAWTEXT  68, 60, "CIRC"
370 DRAWTEXT 120, 60, "ELL"
380 DRAWTEXT 168, 60, "TRI"
390 DRAWTEXT 232, 60, "SPIN"
400 REM row 3: POLYGON + FLOODFILL
410 DRAWTEXT  56, 148, "POLYGON"
420 RECT 140, 156 TO 200, 196
430 FLOODFILL 170, 176
440 DRAWTEXT 208, 170, "FLOODFILL"
450 REM frame + title
460 RECT 0, 0 TO 319, 199
470 DRAWTEXT 56, 120, "RGC-BASIC GRAPHICS TOUR"
480 DRAWTEXT 96, 132, "PRESS Q TO QUIT"
490 REM spinner centre + erase-box geometry
500 CX = 280 : CY = 88
510 EX1 = CX - 15 : EY1 = CY - 15
520 EX2 = CX + 15 : EY2 = CY + 15
530 REM --- animation loop: only spinner changes ---
540 IF KEYDOWN(ASC("Q")) THEN END
550 REM erase just the spinner box (no full-screen CLS = no flicker)
560 COLOR 0
570 FILLRECT EX1, EY1 TO EX2, EY2
580 COLOR 1
590 CIRCLE CX, CY, 14
600 PSET CX, CY
610 RX = CX + INT(12 * COS(T * 3.14159 / 180))
620 RY = CY + INT(12 * SIN(T * 3.14159 / 180))
630 LINE CX, CY TO RX, RY
640 T = T + 6
650 IF T >= 360 THEN T = 0
660 VSYNC
670 GOTO 540
