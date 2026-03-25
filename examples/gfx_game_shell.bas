1 REM ============================================================
2 REM GFX game shell: tile map, PNG player/enemy, HUD, INKEY$ loop
3 REM Map is PETSCII (POKE); actors are 8x8 PNGs (DRAWSPRITE on top).
4 REM Run: ./basic-gfx examples/gfx_game_shell.bas
5 REM Text cell (C,R) on 40x25 grid -> pixel x=C*8, y=R*8 (8px cells)
6 REM Map uses local (PX,PY); screen row = MR+PY, col = MC+PX
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
160 DIM B(99)
170 FOR R = 0 TO MH-1
180 FOR C = 0 TO MW-1
190 READ T
200 B(R*MW+C) = T
210 NEXT C
220 NEXT R
230 GOSUB 6000
240 REM slot 0=HUD 1=player 2=enemy (z: higher draws on top)
250 LOADSPRITE 0,"hud_panel.png"
260 LOADSPRITE 1,"player.png"
270 LOADSPRITE 2,"enemy.png"
280 DRAWSPRITE 0,48,176,200,0,0,48,16
290 GOSUB 6200
300 GOSUB 6120
310 PRINT "{HOME}{WHITE}WASD MOVE ESC QUIT REACH {LIGHT GREEN}G{WHITE} (GOAL)"
320 REM ================== main loop =============================
330 K$ = UCASE$(INKEY$())
340 IF K$ = "" THEN SLEEP 1 : GOTO 330
350 IF K$ = CHR$(27) THEN END
360 QX = PX
370 QY = PY
380 IF K$ = "W" THEN QY = PY-1
390 IF K$ = "S" THEN QY = PY+1
400 IF K$ = "A" THEN QX = PX-1
410 IF K$ = "D" THEN QX = PX+1
420 IF QX = PX AND QY = PY THEN GOTO 330
430 IF QX < 0 OR QX >= MW OR QY < 0 OR QY >= MH THEN GOTO 330
440 IF B(QY*MW+QX) = 1 THEN GOTO 330
450 IF QX = EX AND QY = EY THEN PRINT "{HOME}{RED}CAUGHT!{WHITE}" : END
460 IF B(QY*MW+QX) = 2 THEN PRINT "{HOME}{YELLOW}YOU WIN!{WHITE}" : END
470 TC = PX
480 TR = PY
490 GOSUB 6300
500 PX = QX
510 PY = QY
520 GOSUB 6120
530 TC = EX
540 TR = EY
550 GOSUB 6300
560 REM enemy: step toward player (horizontal first, then vertical)
570 IF EX < PX THEN QX = EX+1 : IF QX < MW THEN IF B(EY*MW+QX) <> 1 THEN EX = QX : GOTO 610
580 IF EX > PX THEN QX = EX-1 : IF QX >= 0 THEN IF B(EY*MW+QX) <> 1 THEN EX = QX : GOTO 610
590 IF EY < PY THEN QY = EY+1 : IF QY < MH THEN IF B(QY*MW+EX) <> 1 THEN EY = QY
600 IF EY > PY THEN QY = EY-1 : IF QY >= 0 THEN IF B(QY*MW+EX) <> 1 THEN EY = QY
610 GOSUB 6200
620 IF EX = PX AND EY = PY THEN PRINT "{HOME}{RED}CAUGHT!{WHITE}" : END
630 GOTO 330
900 DATA 1,1,1,1,1,1,1,1,1,1,1
910 DATA 1,0,0,0,1,0,0,0,0,0,1
920 DATA 1,0,1,0,1,0,1,1,1,0,1
930 DATA 1,0,1,0,0,0,0,0,1,0,1
940 DATA 1,0,1,1,1,1,1,0,1,0,1
950 DATA 1,0,0,0,0,0,0,0,0,0,1
960 DATA 1,0,1,0,1,1,1,0,1,0,1
970 DATA 1,0,0,0,0,0,0,0,2,0,1
980 DATA 1,1,1,1,1,1,1,1,1,1,1
6000 REM ---- draw map only (PETSCII tiles) -------------------
6010 FOR R = 0 TO MH-1
6020 FOR C = 0 TO MW-1
6030 SI = SCR + (MR+R)*40 + (MC+C)
6040 CI = COLR + (MR+R)*40 + (MC+C)
6050 T = B(R*MW+C)
6060 IF T = 1 THEN POKE SI,160 : POKE CI,C_WALL
6070 IF T = 0 THEN POKE SI,32 : POKE CI,C_FLOOR
6080 IF T = 2 THEN POKE SI,7 : POKE CI,C_GOAL
6090 NEXT C
6100 NEXT R
6110 RETURN
6120 REM ---- draw player PNG (8x8) at map cell (PX,PY) ----------
6121 SPX = (MC+PX)*8
6122 SPY = (MR+PY)*8
6123 REM z=100 above enemy (90) so both visible when adjacent
6124 DRAWSPRITE 1,SPX,SPY,100
6125 RETURN
6200 REM ---- draw enemy PNG -----------------------------------
6201 EPX = (MC+EX)*8
6202 EPY = (MR+EY)*8
6203 DRAWSPRITE 2,EPX,EPY,90
6204 RETURN
6300 REM ---- restore map tile at map cell (TC,TR) -------------
6301 SI = SCR + (MR+TR)*40 + (MC+TC)
6302 CI = COLR + (MR+TR)*40 + (MC+TC)
6303 T = B(TR*MW+TC)
6304 IF T = 1 THEN POKE SI,160 : POKE CI,C_WALL
6305 IF T = 0 THEN POKE SI,32 : POKE CI,C_FLOOR
6306 IF T = 2 THEN POKE SI,7 : POKE CI,C_GOAL
6307 RETURN
