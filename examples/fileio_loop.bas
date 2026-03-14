1 REM ============================================================
2 REM  FILE I/O - Reading until end of file (using ST status)
3 REM ============================================================
4 REM  When you don't know how many items are in a file, read in a
5 REM  loop and check ST (status) after each INPUT# or GET#:
6 REM
7 REM    ST = 0   : success, more data may follow
8 REM    ST = 64  : end of file (no more data)
9 REM    ST = 1   : error (e.g. file not open)
10 REM
11 REM  Pattern: OPEN for read, then loop INPUT# ... IF ST <> 0 THEN GOTO done
12 REM ============================================================
13 REM --- Write a list of random numbers to a file ---
14 PRINT "Writing 10 numbers to file..."
15 OPEN 1,1,1,"NUMBERS.DAT"
16 FOR I = 1 TO 10
17   A = RND(0)
18   PRINT A
19   PRINT#1, A
20 NEXT I
21 CLOSE 1
22 REM --- Read them back without knowing the count ---
23 REM     We read one number at a time. When INPUT# hits end of file,
24 REM     ST is set to 64 and the variable gets 0 (or empty for string).
25 PRINT "Reading back until end of file..."
26 OPEN 1,1,0,"NUMBERS.DAT"
27 INPUT#1, N
28 IF ST <> 0 THEN GOTO 31
29 PRINT N
30 GOTO 27
31 CLOSE 1
32 REM     Line 28: "IF ST <> 0 THEN GOTO 31" means:
33 REM     "If something went wrong or we hit end of file, jump to 31 and close."
34 PRINT "Done."
35 END
