1 REM GFX INKEY$ DEMO: non-blocking keypress input
2 REM Run with: ./basic-gfx -petscii examples/gfx_inkey_demo.bas
3 REM
4 REM INKEY$() returns a 1-character string when a keypress is available,
5 REM or "" if none. Letters may be upper or lower case — UCASE$ matches WASD.
6 REM Compare to gfx_key_demo.bas: PEEK(56320+n) uses n = ASCII of UPPERCASE
7 REM letter (W=87, A=65, S=83, D=68, ESC=27). INKEY$ gives the real char.
10 SCR = 1024
20 COL = 55296
30 X = 20
40 Y = 12
50 C = 1
60 BACKGROUND 6
70 COLOR 14
80 PRINT "{CLR}{WHITE}INKEY$ DEMO (WASD moves, ESC exits)"
90 REM Draw initial @ at (X,Y)
100 POKE SCR + Y*40 + X, 0
110 POKE COL + Y*40 + X, C
120 REM Loop
130 K$ = INKEY$()
140 IF K$ = "" THEN SLEEP 1 : GOTO 130
150 K$ = UCASE$(K$)
160 K = ASC(K$)
170 IF K = 27 THEN END
180 NX = X : NY = Y
190 IF K = 87 THEN NY = Y - 1
200 IF K = 83 THEN NY = Y + 1
210 IF K = 65 THEN NX = X - 1
220 IF K = 68 THEN NX = X + 1
230 IF NX < 0 THEN NX = 0
240 IF NX > 39 THEN NX = 39
250 IF NY < 0 THEN NY = 0
260 IF NY > 24 THEN NY = 24
270 IF NX = X AND NY = Y THEN GOTO 130
280 POKE SCR + Y*40 + X, 32
290 X = NX : Y = NY
300 POKE SCR + Y*40 + X, 0
310 GOTO 130
