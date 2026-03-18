1 REM GFX KEY DEMO: poll host keyboard via PEEK and move a character
2 REM Run with: ./basic-gfx examples/gfx_key_demo.bas
3 REM
4 REM Keyboard map (via gfx video peek):
5 REM   PEEK(56320 + ASCII) is 1 while that key is held down.
6 REM   Supported here: WASD, ESC.
10 SCR = 1024
20 COL = 55296
30 X = 20
40 Y = 12
50 C = 1
60 REM Clear screen to spaces and set colour to light blue (14)
70 FOR I = 0 TO 999
80 POKE SCR + I, 32
90 POKE COL + I, 14
100 NEXT I
110 REM Draw initial @
120 POKE SCR + Y*40 + X, 0
130 POKE COL + Y*40 + X, C
140 REM Main loop
150 REM ESC (27) to exit, WASD to move
160 IF PEEK(56320+27) <> 0 THEN END
170 NX = X
180 NY = Y
190 IF PEEK(56320+87) <> 0 THEN NY = Y - 1
200 IF PEEK(56320+83) <> 0 THEN NY = Y + 1
210 IF PEEK(56320+65) <> 0 THEN NX = X - 1
220 IF PEEK(56320+68) <> 0 THEN NX = X + 1
230 IF NX < 0 THEN NX = 0
240 IF NX > 39 THEN NX = 39
250 IF NY < 0 THEN NY = 0
260 IF NY > 24 THEN NY = 24
270 IF NX = X AND NY = Y THEN GOTO 320
280 REM Erase old, draw new
290 POKE SCR + Y*40 + X, 32
300 X = NX : Y = NY
310 POKE SCR + Y*40 + X, 0
320 SLEEP 1
330 GOTO 160

