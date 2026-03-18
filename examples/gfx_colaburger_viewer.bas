0 PRINT CHR$(147)
1 REM GFX viewer for colaburger.seq (PETSCII stream with colour/control codes)
2 REM Run: ./basic-gfx -petscii examples/gfx_colaburger_viewer.bas
3 REM Wrap at 40 columns (C64 screen width)
4 OPEN 1,1,0,"examples/colaburger.seq"
5 L=0
6 GET#1,C$
7 IF ST<>0 THEN GOTO 16
8 IF LEN(C$)=0 THEN GOTO 6
9 A=ASC(C$):IF A=13 THEN PRINT:L=0:GOTO 6
10 PRINT CHR$(A);
11 IF A=20 THEN L=L-1
12 IF A<32 THEN GOTO 15
13 IF A>126 AND A<160 THEN GOTO 15
14 L=L+1:IF L>=40 THEN PRINT CHR$(13);:L=0
15 GOTO 6
16 CLOSE 1
17 PRINT
18 SLEEP 1000
19 END

