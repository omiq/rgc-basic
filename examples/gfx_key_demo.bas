1 REM GFX KEY DEMO: poll host keyboard via PEEK and move a character
2 REM Run with: ./basic-gfx examples/gfx_key_demo.bas
3 REM
4 REM PEEK(GFX_KEY_BASE + n) reads key_state[n]: 1 while key is held.
5 REM GFX_KEY_BASE is 56320 (0xDC00). For letters, n is ASCII of the
6 REM UPPERCASE key (same as ASC("W") not PETSCII screen code): W=87 A=65 S=83 D=68.
7 REM ESC = 27. This matches Raylib/basic-gfx and canvas wasmGfxKeyIndex().
10 SCR = 1024
20 COL = 55296
30 X = 20
40 Y = 12
50 C = 1
60 REM Optional named constants (same numbers as gfx_inkey_demo after UCASE$)
70 REM KW=87 : KA=65 : KS=83 : KD=68 : KESC=27
80 REM Clear screen to spaces and set colour to light blue (14)
90 FOR I = 0 TO 999
100 POKE SCR + I, 32
110 POKE COL + I, 14
120 NEXT I
130 REM Draw initial @
140 POKE SCR + Y*40 + X, 0
150 POKE COL + Y*40 + X, C
160 REM Main loop: ESC to exit, WASD to move (hold key to repeat each SLEEP)
190 IF PEEK(56320+27) <> 0 THEN END
200 NX = X
210 NY = Y
220 IF PEEK(56320+87) <> 0 THEN NY = Y - 1
230 IF PEEK(56320+83) <> 0 THEN NY = Y + 1
240 IF PEEK(56320+65) <> 0 THEN NX = X - 1
250 IF PEEK(56320+68) <> 0 THEN NX = X + 1
260 IF NX < 0 THEN NX = 0
270 IF NX > 39 THEN NX = 39
280 IF NY < 0 THEN NY = 0
290 IF NY > 24 THEN NY = 24
300 IF NX = X AND NY = Y THEN GOTO 340
310 REM Erase old, draw new
320 POKE SCR + Y*40 + X, 32
330 X = NX : Y = NY
340 POKE SCR + Y*40 + X, 0
350 SLEEP 1
360 GOTO 190
