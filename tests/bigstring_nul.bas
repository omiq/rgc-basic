10 REM bigstring: embedded NUL round-trip
20 S$ = "A\0B" + "C\0D"
30 IF LEN(S$) <> 6 THEN PRINT "FAIL len=";LEN(S$): GOTO 200
40 IF ASC(MID$(S$, 2, 1)) <> 0 THEN PRINT "FAIL byte2=";ASC(MID$(S$,2,1)): GOTO 200
50 IF ASC(MID$(S$, 5, 1)) <> 0 THEN PRINT "FAIL byte5=";ASC(MID$(S$,5,1)): GOTO 200
60 PRINT "OK bigstring_nul"
70 END
200 PRINT "FAIL bigstring_nul"
