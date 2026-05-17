10 REM bigstring: grow past 4K with maxstr unlimited
20 #OPTION MAXSTR UNLIMITED
30 S$ = ""
40 FOR I = 1 TO 10000
50   S$ = S$ + "x"
60 NEXT I
70 IF LEN(S$) <> 10000 THEN PRINT "FAIL len=";LEN(S$): GOTO 200
80 PRINT "OK bigstring_grow"
90 END
200 PRINT "FAIL bigstring_grow"
