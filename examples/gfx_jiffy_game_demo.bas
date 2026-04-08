1 REM GFX JIFFY CLOCK DEMO: smooth player + simple enemy motion
2 REM Run with: ./basic-gfx -petscii examples/gfx_jiffy_game_demo.bas
3 REM Controls: hold W/A/S/D to move, ESC to quit
4 REM
5 REM Uses TI (60Hz) to update at a steady rate regardless of input bursts.
6 REM Each line number must be unique — duplicate numbers replace earlier lines.
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
210 REM LT one behind TI so first IF T<=LT passes (canvas TI = wall ms/60Hz)
220 LT = TI - 1
230 PSTEP = 3
235 PMOVE = TI
240 ESTEP = 6
245 ELT = TI

250 REM Initial draw
260 POKE SCR + PY*WIDTH + PX, 0
270 POKE COL + PY*WIDTH + PX, PCOL
280 POKE SCR + EY*WIDTH + EX0, ECH
290 POKE COL + EY*WIDTH + EX0, ECOL
295 LXE = EX0

300 REM Main loop
310 IF PEEK(KEYBASE+27) <> 0 THEN END
320 T = TI
330 REM Wait until a new jiffy (TI>T); "=" alone can spin on same bucket
340 IF T <= LT THEN SLEEP 1 : GOTO 310

350 REM --- Enemy updates at a steady rate (about 10 fps) ---
355 IF T < ELT + ESTEP THEN GOTO 398
357 ELT = T
360 REM Use seconds-ish phase: (T/PERIOD)*2*pi
370 Q = INT(T / PERIOD)
380 PH = T - Q * PERIOD
390 EX = EX0 + INT(AMP * SIN(6.28318 * (PH / PERIOD)))
392 IF EX < 0 THEN EX = 0
394 IF EX > 39 THEN EX = 39

396 REM --- Player updates at fixed speed while key held ---
398 NX = PX : NY = PY
400 IF T < PMOVE + PSTEP THEN GOTO 500
420 IF PEEK(KEYBASE+87) <> 0 THEN NY = PY - 1
430 IF PEEK(KEYBASE+83) <> 0 THEN NY = PY + 1
440 IF PEEK(KEYBASE+65) <> 0 THEN NX = PX - 1
450 IF PEEK(KEYBASE+68) <> 0 THEN NX = PX + 1
460 IF NX < 0 THEN NX = 0
470 IF NX > 39 THEN NX = 39
480 PMOVE = T
500 IF NY < 2 THEN NY = 2
510 IF NY > 24 THEN NY = 24

520 REM --- Redraw only when positions change ---
530 IF NX <> PX OR NY <> PY THEN POKE SCR + PY*WIDTH + PX, 32

540 IF NX <> PX OR NY <> PY THEN PX = NX : PY = NY

550 POKE SCR + PY*WIDTH + PX, 0
560 POKE COL + PY*WIDTH + PX, PCOL

570 REM Draw enemy first, then clear old to avoid "blank" tear on concurrent render
580 POKE SCR + EY*WIDTH + EX, ECH
590 POKE COL + EY*WIDTH + EX, ECOL
600 IF EX <> LXE THEN POKE SCR + EY*WIDTH + LXE, 32

610 REM HUD (top right): show TI$ and TI
620 TEXTAT 22,0,"TI$=" + TI$ + "  "
630 TEXTAT 22,1,"TI=" + STR$(TI) + "    "

640 REM Save last positions/time and loop
650 LXE = EX
660 LT = T
670 GOTO 310
