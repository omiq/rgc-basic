1 REM =========================================================
2 REM gfx_scroll_demo — smooth bitmap scroll via IMAGE COPY
3 REM
4 REM Pattern (AMOS-style): build an oversized off-screen world
5 REM bitmap, then blit a 320x200 window from it onto the visible
6 REM bitmap each frame at varying offset. Wraps horizontally.
7 REM
8 REM Commands: IMAGE NEW, IMAGE COPY, PSET, CLS
9 REM Keys: Q quit (scrolls automatically)
10 REM =========================================================
20 PRINT CHR$(14)
30 REM --- 1. Paint a 16x16 "tile" into visible (slot 0) ---
40 CLS
50 FOR Y = 0 TO 15 : PSET 0,Y : PSET 15,Y : NEXT Y
60 FOR X = 0 TO 15 : PSET X,0 : PSET X,15 : NEXT X
70 PSET 7,7 : PSET 8,8 : PSET 7,8 : PSET 8,7
80 REM --- 2. Capture it into off-screen surface 1 ---
90 IMAGE NEW 1, 16, 16
100 IMAGE COPY 0, 0, 0, 16, 16 TO 1, 0, 0
110 REM --- 3. Build a 640x200 world (surface 2) by stamping tiles ---
120 IMAGE NEW 2, 640, 200
130 FOR R = 0 TO 12
140 FOR C = 0 TO 39
150 IMAGE COPY 1, 0, 0, 16, 16 TO 2, C*16, R*16
160 NEXT C
170 NEXT R
180 CLS
190 REM --- 4. Scroll: blit 320x200 window from surface 2 each frame ---
200 XO = 0
210 K$ = UCASE$(INKEY$())
220 IF K$ = "Q" THEN END
230 IMAGE COPY 2, XO, 0, 320, 200 TO 0, 0, 0
240 XO = XO + 2
250 IF XO >= 320 THEN XO = 0
260 SLEEP 2
270 GOTO 210
