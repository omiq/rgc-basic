0 PRINT CHR$(147)
1 REM GFX viewer for colaburger.seq (PETSCII stream with colour/control codes)
2 REM Run: ./basic-gfx -petscii -charset lower examples/gfx_colaburger_viewer.bas
3 REM SCREENCODES ON: bytes are PETSCII (CHR$/PRINT stream); converts to screen codes
4 SCREENCODES ON
5 REM Cyan background and 40-column wrap to match colaburger art
6 BACKGROUND 3
7 OPEN 1,1,0,"examples/colaburger.seq"
8 L=0
9 GET#1,C$
10 IF ST<>0 THEN GOTO 19
11 IF LEN(C$)=0 THEN GOTO 9
12 A=ASC(C$):IF A=13 THEN PRINT:L=0:GOTO 9
13 PRINT CHR$(A);
14 IF A=20 THEN L=L-1
15 IF A<32 THEN GOTO 18
16 IF A>126 AND A<160 THEN GOTO 18
17 L=L+1:IF L>=40 THEN PRINT CHR$(13);:L=0
18 GOTO 9
19 CLOSE 1
20 PRINT
21 TEXTAT 0,24,"DONE. PRESS ANY KEY (ESC TO QUIT)"
22 K$ = INKEY$(): IF K$="" THEN SLEEP 1 : GOTO 22
23 END

