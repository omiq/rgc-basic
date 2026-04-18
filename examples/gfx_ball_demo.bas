1 REM =========================================================
2 REM gfx_ball_demo — bouncing ball using only bitmap primitives
3 REM
4 REM Demonstrates FILLCIRCLE (ball), RECT (playfield frame), LINE
5 REM (trail segments), DRAWTEXT (HUD), CLS (per-frame clear),
6 REM KEYDOWN (pause + quit).
7 REM
8 REM Keys: SPACE pause/resume, Q quit
9 REM =========================================================
10 SCREEN 1
20 BX = 160 : BY = 100 : BR = 6
30 VX = 3 : VY = 2
40 PAUSED = 0
50 BOUNCES = 0
60 REM --- main loop ---
70 IF KEYDOWN(ASC("Q")) THEN END
80 IF KEYPRESS(ASC(" ")) THEN PAUSED = 1 - PAUSED
90 IF PAUSED THEN GOTO 200
100 BX = BX + VX
110 BY = BY + VY
120 IF BX - BR < 8  THEN BX = 8 + BR        : VX = -VX : BOUNCES = BOUNCES + 1
130 IF BX + BR > 311 THEN BX = 311 - BR     : VX = -VX : BOUNCES = BOUNCES + 1
140 IF BY - BR < 8  THEN BY = 8 + BR        : VY = -VY : BOUNCES = BOUNCES + 1
150 IF BY + BR > 175 THEN BY = 175 - BR     : VY = -VY : BOUNCES = BOUNCES + 1
200 CLS
210 REM playfield frame
220 RECT 8, 8 TO 311, 175
230 REM ball
240 FILLCIRCLE BX, BY, BR
250 REM HUD at the bottom
260 DRAWTEXT 12, 182, "BOUNCES "
270 DRAWTEXT 80, 182, STR$(BOUNCES)
280 IF PAUSED THEN DRAWTEXT 200, 182, "PAUSED"
290 IF PAUSED = 0 THEN DRAWTEXT 200, 182, "Q QUIT  SPACE PAUSE"
300 SLEEP 1
310 GOTO 70
