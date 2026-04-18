1 REM =========================================================
2 REM gfx_parallax_demo — 3-band parallax scroll via IMAGE COPY
3 REM
4 REM Three 320-wide bands scroll at different speeds:
5 REM   sky    (y 0..59)    — 1 px/tick (slowest / farthest)
6 REM   mid    (y 60..139)  — 2 px/tick
7 REM   ground (y 140..199) — 4 px/tick (fastest / closest)
8 REM
9 REM Each band lives in its own off-screen surface twice the
10 REM viewport width so IMAGE COPY with a wrapping offset blits a
11 REM seamless loop onto the visible bitmap.
12 REM
13 REM Keys: Q quit
14 REM =========================================================
20 SCREEN 1 : REM hi-res bitmap mode
30 REM --- Build each band in a separate surface ---
40 IMAGE NEW 1, 640, 60   : REM sky
50 IMAGE NEW 2, 640, 80   : REM mid
60 IMAGE NEW 3, 640, 60   : REM ground
70 REM paint markers into visible, capture to each band, then clear
80 CLS
90 FOR X = 0 TO 319 STEP 64 : FOR Y = 0 TO 59
100 PSET X,Y : PSET X+1,Y
110 NEXT Y : NEXT X
120 FOR I = 0 TO 1
130 IMAGE COPY 0, 0, 0, 320, 60 TO 1, I*320, 0
140 NEXT I
150 CLS
160 FOR X = 0 TO 319 STEP 24 : FOR Y = 0 TO 79
170 PSET X,Y
180 NEXT Y : NEXT X
190 FOR I = 0 TO 1
200 IMAGE COPY 0, 0, 0, 320, 80 TO 2, I*320, 0
210 NEXT I
220 CLS
230 FOR X = 0 TO 319 STEP 8 : FOR Y = 0 TO 59
240 PSET X,Y
250 NEXT Y : NEXT X
260 FOR I = 0 TO 1
270 IMAGE COPY 0, 0, 0, 320, 60 TO 3, I*320, 0
280 NEXT I
290 CLS
300 REM --- Main loop: advance each band offset, blit each band ---
310 XS = 0 : XM = 0 : XG = 0
320 K$ = UCASE$(INKEY$())
330 IF K$ = "Q" THEN END
340 IMAGE COPY 1, XS, 0, 320,  60 TO 0, 0,   0
350 IMAGE COPY 2, XM, 0, 320,  80 TO 0, 0,  60
360 IMAGE COPY 3, XG, 0, 320,  60 TO 0, 0, 140
370 XS = XS + 1 : IF XS >= 320 THEN XS = 0
380 XM = XM + 2 : IF XM >= 320 THEN XM = 0
390 XG = XG + 4 : IF XG >= 320 THEN XG = 0
400 SLEEP 2
410 GOTO 320
