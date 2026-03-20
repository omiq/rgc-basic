#OPTION maxstr 255
REM Test #OPTION maxstr 255 - strings truncated to 255
PRINT "Testing #OPTION maxstr 255..."
A$ = STRING$(300, "X")
IF LEN(A$) = 255 THEN PRINT "OK: STRING$(300) truncated to 255"
IF LEN(A$) <> 255 THEN PRINT "FAIL: got"; LEN(A$); "expected 255"
B$ = "A" + STRING$(300, "B")
IF LEN(B$) = 255 THEN PRINT "OK: concat truncated to 255"
PRINT "maxstr 255 test done."
