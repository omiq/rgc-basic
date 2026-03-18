1 REM GFX INKEY$ DEMO: non-blocking keypress input
2 REM Run with: ./basic-gfx -petscii examples/gfx_inkey_demo.bas
3 REM
4 REM INKEY$() returns a 1-character string when a keypress is available,
5 REM or "" if no key was pressed since last call.
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
150 K = ASC(K$)
160 IF K = 27 THEN END
170 NX = X : NY = Y
180 IF K = 87 THEN NY = Y - 1
190 IF K = 83 THEN NY = Y + 1
200 IF K = 65 THEN NX = X - 1
210 IF K = 68 THEN NX = X + 1
220 IF NX < 0 THEN NX = 0
230 IF NX > 39 THEN NX = 39
240 IF NY < 0 THEN NY = 0
250 IF NY > 24 THEN NY = 24
260 IF NX = X AND NY = Y THEN GOTO 130
270 POKE SCR + Y*40 + X, 32
280 X = NX : Y = NY
290 POKE SCR + Y*40 + X, 0
300 GOTO 130

