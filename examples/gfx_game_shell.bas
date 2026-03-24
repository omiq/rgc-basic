1 REM ============================================================
2 REM GFX game shell: tile map, player @, enemy *, HUD PNG, INKEY$ loop
3 REM Same *kind* of idea as dungeon.bas (map + movement), fresh code.
4 REM Run: ./basic-gfx examples/gfx_game_shell.bas
5 REM Text row R, col C: index = 1024 + R*40 + C
6 REM DRAWSPRITE x,y = pixels; top of text row R is y = R*8
7 REM ===========================================================
20 PRINT CHR$(14)
30 SCR = 1024
40 COLR = 55296
50 MW = 11
60 MH = 9
70 MC = 14
80 MR = 6
90 PX = 5
100 PY = 3
110 EX = 5
120 EY = 1
130 C_WALL = 11
140 C_FLOOR = 6
150 C_GOAL = 13
160 C_PLAYER = 1
170 C_ENEMY = 2
180 DIM B(99)
190 FOR R = 0 TO MH-1
200 FOR C = 0 TO MW-1
210 READ T
220 B(R*MW+C) = T
230 NEXT C
240 NEXT R
250 GOSUB 6000
260 LOADSPRITE 0,"hud_panel.png"
270 DRAWSPRITE 0,48,176,200,0,0,48,16
280 GOSUB 6120
290 GOSUB 6200
300 PRINT "{HOME}{WHITE}WASD move  ESC quit  reach {LIGHT GREEN}G{WHITE} (goal)"
310 REM ================== main loop =============================
320 K$ = INKEY$()
330 IF K$ = "" THEN SLEEP 1 : GOTO 320
340 IF K$ = CHR$(27) THEN END
350 QX = PX
360 QY = PY
370 IF K$ = "W" THEN QY = PY-1
380 IF K$ = "S" THEN QY = PY+1
390 IF K$ = "A" THEN QX = PX-1
400 IF K$ = "D" THEN QX = PX+1
410 IF QX = PX AND QY = PY THEN GOTO 320
420 IF QX < 0 OR QX >= MW OR QY < 0 OR QY >= MH THEN GOTO 320
430 IF B(QY*MW+QX) = 1 THEN GOTO 320
440 IF QX = EX AND QY = EY THEN PRINT "{HOME}{RED}Caught!{WHITE}" : END
450 IF B(QY*MW+QX) = 2 THEN PRINT "{HOME}{YELLOW}You win!{WHITE}" : END
460 TC = PX
470 TR = PY
480 GOSUB 6300
490 PX = QX
500 PY = QY
510 GOSUB 6120
520 TC = EX
530 TR = EY
540 GOSUB 6300
550 REM enemy: step toward player (try horizontal, then vertical)
560 IF EX < PX THEN QX = EX+1 : IF QX < MW THEN IF B(EY*MW+QX) <> 1 THEN EX = QX : GOTO 600
570 IF EX > PX THEN QX = EX-1 : IF QX >= 0 THEN IF B(EY*MW+QX) <> 1 THEN EX = QX : GOTO 600
580 IF EY < PY THEN QY = EY+1 : IF QY < MH THEN IF B(QY*MW+EX) <> 1 THEN EY = QY
590 IF EY > PY THEN QY = EY-1 : IF QY >= 0 THEN IF B(QY*MW+EX) <> 1 THEN EY = QY
600 GOSUB 6200
610 IF EX = PX AND EY = PY THEN PRINT "{HOME}{RED}Caught!{WHITE}" : END
620 GOTO 320
900 DATA 1,1,1,1,1,1,1,1,1,1,1
910 DATA 1,0,0,0,1,0,0,0,0,0,1
920 DATA 1,0,1,0,1,0,1,1,1,0,1
930 DATA 1,0,1,0,0,0,0,0,1,0,1
940 DATA 1,0,1,1,1,1,1,0,1,0,1
950 DATA 1,0,0,0,0,0,0,0,0,0,1
960 DATA 1,0,1,0,1,1,1,0,1,0,1
970 DATA 1,0,0,0,0,0,0,0,2,0,1
980 DATA 1,1,1,1,1,1,1,1,1,1,1
6000 REM ---- draw map only ------------------------------------
6010 FOR R = 0 TO MH-1
6020 FOR C = 0 TO MW-1
6030 SI = SCR + (MR+R)*40 + (MC+C)
6040 CI = COLR + (MR+R)*40 + (MC+C)
6050 T = B(R*MW+C)
6060 IF T = 1 THEN POKE SI,160 : POKE CI,C_WALL
6070 IF T = 0 THEN POKE SI,32 : POKE CI,C_FLOOR
6080 IF T = 2 THEN POKE SI,7 : POKE CI,C_GOAL
6090 NEXT C
6105 NEXT R
6110 RETURN
6120 REM ---- draw player @ ------------------------------------
6121 SI = SCR + (MR+PY)*40 + (MC+PX)
6122 POKE SI,0
6123 POKE COLR + (MR+PY)*40 + (MC+PX),C_PLAYER
6124 RETURN
6200 REM ---- draw enemy * -------------------------------------
6201 SI = SCR + (MR+EY)*40 + (MC+EX)
6202 POKE SI,42
6203 POKE COLR + (MR+EY)*40 + (MC+EX),C_ENEMY
6204 RETURN
6300 REM ---- restore map tile at (TC,TR) ---------------------
6301 SI = SCR + (MR+TR)*40 + (MC+TC)
6302 CI = COLR + (MR+TR)*40 + (MC+TC)
6303 T = B(TR*MW+TC)
6304 IF T = 1 THEN POKE SI,160 : POKE CI,C_WALL
6305 IF T = 0 THEN POKE SI,32 : POKE CI,C_FLOOR
6306 IF T = 2 THEN POKE SI,7 : POKE CI,C_GOAL
6307 RETURN
