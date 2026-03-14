1 REM ============================================================
2 REM  FILE I/O - Reading one character at a time (GET#)
3 REM ============================================================
4 REM  GET# reads a single character (byte) from a file into a string
5 REM  variable. Use it when you need character-by-character processing,
6 REM  or when you want to read raw bytes (e.g. simple binary data).
7 REM
8 REM    GET# fileNumber, stringVar
9 REM
10 REM  After GET#, check ST: 0 = got a character, 64 = end of file
11 REM  (stringVar will be empty at EOF).
12 REM ============================================================
13 REM --- Write three characters to a file ---
14 REM     PRINT# with ; writes without a newline, so "X","Y","Z" end up
15 REM     as three bytes (plus newline after the last PRINT# without ;).
16 OPEN 1,1,1,"CHARS.DAT"
17 PRINT#1, "X";
18 PRINT#1, "Y";
19 PRINT#1, "Z"
20 CLOSE 1
21 REM --- Read them back one character at a time with GET# ---
22 OPEN 2,1,0,"CHARS.DAT"
23 GET#2, A$
24 GET#2, B$
25 GET#2, C$
26 CLOSE 2
27 REM --- Show what we read ---
28 PRINT "First  char: '"; A$; "'"
29 PRINT "Second char: '"; B$; "'"
30 PRINT "Third  char: '"; C$; "'"
31 IF A$="X" AND B$="Y" AND C$="Z" THEN PRINT "OK - all correct!"
32 REM --- Optional: read until EOF with GET# (uncomment to try) ---
33 REM 50 OPEN 1,1,0,"CHARS.DAT"
34 REM 51 GET#1, C$
35 REM 52 IF ST <> 0 THEN GOTO 55
36 REM 53 PRINT C$;
37 REM 54 GOTO 51
38 REM 55 CLOSE 1
39 REM 56 PRINT
40 END
