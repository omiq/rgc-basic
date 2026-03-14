0 PRINT CHR$(147)
1 REM Read colaburger.seq (raw PETSCII) and display
2 REM Run: basic -petscii-plain examples/colaburger_viewer.bas  (no ANSI = strict alignment)
3 REM Wrap at 40 visible columns (like C64: only printable/graphic bytes advance cursor)
4 OPEN 1,1,0,"examples/colaburger.seq"
5 L=0
6 GET#1,C$
7 IF ST<>0 THEN GOTO 16
8 IF LEN(C$)=0 THEN GOTO 6
9 A=ASC(C$):IF A=13 THEN PRINT:L=0:GOTO 6
10 PRINT CHR$(A);
11 REM Wrap after 40 visible columns (cursor-advancing chars only); C64 control/color bytes do not advance cursor
12 IF A<32 THEN GOTO 15
13 IF A>126 AND A<160 THEN GOTO 15
14 L=L+1:IF L>=40 THEN PRINT:L=0
15 GOTO 6
16 CLOSE 1
17 PRINT
18 END
