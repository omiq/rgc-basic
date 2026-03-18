1 REM GFX JIFFY CLOCK DEMO: smooth player + simple enemy motion
2 REM Run with: ./basic-gfx -petscii examples/gfx_jiffy_game_demo.bas
3 REM Controls: hold W/A/S/D to move, ESC to quit
4 REM
5 REM Uses TI (60Hz) to update at a steady rate regardless of input bursts.
10 SCR = 1024
20 COL = 55296
30 WIDTH = 40
40 HEIGHT = 25
50 KEYBASE = 56320
60 BACKGROUND 6
70 COLOR 14
80 PRINT "{CLR}{WHITE}JIFFY CLOCK DEMO  (WASD MOVE, ESC QUITS)"
90 PRINT "{CYAN}PLAYER IS '@'   ENEMY IS 'X' (SINE WAVE)"

100 REM Player state
110 PX = 5
120 PY = 12
130 PCOL = 1

140 REM Enemy state (sine wave in X)
150 EX0 = 20
160 EY = 12
170 ECOL = 2
180 AMP = 4
190 PERIOD = 180
195 ECH = 160

200 REM Timing (in jiffies)
210 LT = TI
220 PSTEP = 3
225 PMOVE = LT
226 ESTEP = 6
227 ELT = LT

230 REM Initial draw
240 POKE SCR + PY*WIDTH + PX, 0
250 POKE COL + PY*WIDTH + PX, PCOL
260 POKE SCR + EY*WIDTH + EX0, ECH
270 POKE COL + EY*WIDTH + EX0, ECOL
275 LXE = EX0

280 REM Main loop
290 IF PEEK(KEYBASE+27) <> 0 THEN END
300 T = TI
310 IF T = LT THEN SLEEP 1 : GOTO 290

320 REM --- Enemy updates at a steady rate (about 10 fps) ---
325 IF T < ELT + ESTEP THEN GOTO 370
327 ELT = T
330 REM Use seconds-ish phase: (T/PERIOD)*2*pi
340 Q = INT(T / PERIOD)
350 PH = T - Q * PERIOD
360 EX = EX0 + INT(AMP * SIN(6.28318 * (PH / PERIOD)))
370 IF EX < 0 THEN EX = 0
380 IF EX > 39 THEN EX = 39

370 REM --- Player updates at fixed speed while key held ---
380 NX = PX : NY = PY
390 IF T < PMOVE + PSTEP THEN GOTO 470
400 IF PEEK(KEYBASE+87) <> 0 THEN NY = PY - 1
410 IF PEEK(KEYBASE+83) <> 0 THEN NY = PY + 1
420 IF PEEK(KEYBASE+65) <> 0 THEN NX = PX - 1
430 IF PEEK(KEYBASE+68) <> 0 THEN NX = PX + 1
440 IF NX < 0 THEN NX = 0
450 IF NX > 39 THEN NX = 39
460 PMOVE = T
470 IF NY < 2 THEN NY = 2
480 IF NY > 24 THEN NY = 24

490 REM --- Redraw only when positions change ---
500 IF NX <> PX OR NY <> PY THEN POKE SCR + PY*WIDTH + PX, 32

520 IF NX <> PX OR NY <> PY THEN PX = NX : PY = NY

530 POKE SCR + PY*WIDTH + PX, 0
540 POKE COL + PY*WIDTH + PX, PCOL

550 REM Draw enemy first, then clear old to avoid "blank" tear on concurrent render
560 POKE SCR + EY*WIDTH + EX, ECH
570 POKE COL + EY*WIDTH + EX, ECOL
580 IF EX <> LXE THEN POKE SCR + EY*WIDTH + LXE, 32

600 REM HUD (top right): show TI$ and TI
610 TEXTAT 22,0,"TI$=" + TI$ + "  "
620 TEXTAT 22,1,"TI=" + STR$(TI) + "    "

630 REM Save last positions/time and loop
640 LXE = EX
650 LT = T
660 GOTO 290

