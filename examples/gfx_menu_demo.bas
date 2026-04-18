1 REM =========================================================
2 REM gfx_menu_demo — per-row + per-char PAPER/COLOR demo
3 REM
4 REM Shows both modes of colour attribute control:
5 REM   1. Per-row: highlighted selection bar via PAPER on a full
6 REM      LOCATE + PRINT line.
7 REM   2. Per-character: rainbow title + coloured border chars,
8 REM      each PRINT fragment using a different PAPER/COLOR.
9 REM
10 REM Keys: up/down or W/S cycle selection, Q quits.
11 REM =========================================================
20 BACKGROUND 6 : CLS
30 DIM M$(4)
40 M$(0) = "NEW GAME"
50 M$(1) = "LOAD"
60 M$(2) = "OPTIONS"
70 M$(3) = "CREDITS"
80 M$(4) = "QUIT"
90 SEL = 0
100 REM --- main loop (redraw every tick so selection updates show) ---
110 GOSUB 1000 : REM draw frame + menu
120 IF KEYDOWN(ASC("Q")) THEN CLS : END
130 IF KEYDOWN(KEY_DOWN) OR KEYDOWN(ASC("S")) THEN SEL = SEL + 1 : GOSUB 900
140 IF KEYDOWN(KEY_UP) OR KEYDOWN(ASC("W")) THEN SEL = SEL - 1 : GOSUB 900
150 VSYNC
160 GOTO 110
900 REM --- wrap selection + small debounce ---
910 IF SEL < 0 THEN SEL = 4
920 IF SEL > 4 THEN SEL = 0
930 FOR D = 1 TO 6 : VSYNC : NEXT D
940 RETURN
1000 REM --- draw frame + menu (HOME, not CLS, so no flicker) ---
1010 PRINT "{HOME}";
1020 REM per-character rainbow title: one PRINT fragment per letter
1030 LOCATE 12, 2
1040 PAPER 0 : COLOR 2 : PRINT "R";
1050 PAPER 0 : COLOR 8 : PRINT "G";
1060 PAPER 0 : COLOR 7 : PRINT "C";
1070 PAPER 0 : COLOR 1 : PRINT " ";
1080 PAPER 0 : COLOR 5 : PRINT "B";
1090 PAPER 0 : COLOR 13 : PRINT "A";
1100 PAPER 0 : COLOR 3 : PRINT "S";
1110 PAPER 0 : COLOR 14 : PRINT "I";
1120 PAPER 0 : COLOR 4 : PRINT "C"
1130 REM border row: corner + dashes + corner, all white on black
1140 LOCATE 6, 5
1150 PAPER 0 : COLOR 1 : PRINT "┌";
1160 FOR I = 1 TO 24 : PRINT "─"; : NEXT I
1170 PRINT "┐"
1180 REM menu items: selected row uses PAPER 1 (white bg) per-row
1190 FOR I = 0 TO 4
1200 LOCATE 6, 6 + I
1210 IF I = SEL THEN GOSUB 1400 ELSE GOSUB 1500
1220 NEXT I
1230 REM bottom border
1240 LOCATE 6, 11
1250 PAPER 0 : COLOR 1 : PRINT "└";
1260 FOR I = 1 TO 24 : PRINT "─"; : NEXT I
1270 PRINT "┘"
1280 REM footer: per-character tint on hint
1290 LOCATE 4, 20
1300 PAPER 6 : COLOR 15 : PRINT "keys: ";
1310 PAPER 6 : COLOR 7 : PRINT "W/S";
1320 PAPER 6 : COLOR 15 : PRINT " move  ";
1330 PAPER 6 : COLOR 7 : PRINT "Q";
1340 PAPER 6 : COLOR 15 : PRINT " quit"
1350 RETURN
1400 REM draw selected menu row: left border white on black, item
1410 REM white on RED (row highlight), right border white on black
1420 PAPER 0 : COLOR 1 : PRINT "│";
1430 PAPER 2 : COLOR 1 : PRINT " > ";
1440 PAPER 2 : COLOR 1 : PRINT M$(I);
1450 L = LEN(M$(I))
1460 FOR J = 1 TO 21 - L : PRINT " "; : NEXT J
1470 PAPER 0 : COLOR 1 : PRINT "│"
1480 RETURN
1500 REM draw plain menu row: all blue bg, white text
1510 PAPER 0 : COLOR 1 : PRINT "│";
1520 PAPER 6 : COLOR 1 : PRINT "   ";
1530 PAPER 6 : COLOR 15 : PRINT M$(I);
1540 L = LEN(M$(I))
1550 FOR J = 1 TO 21 - L : PRINT " "; : NEXT J
1560 PAPER 0 : COLOR 1 : PRINT "│"
1570 RETURN

