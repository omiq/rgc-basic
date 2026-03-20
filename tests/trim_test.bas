REM Test TRIM$, LTRIM$, RTRIM$
PRINT "Testing TRIM..."
A$ = "  hello  "
B$ = TRIM$(A$)
IF B$ = "hello" THEN PRINT "OK: TRIM$"
B$ = LTRIM$(A$)
IF B$ = "hello  " THEN PRINT "OK: LTRIM$"
B$ = RTRIM$(A$)
IF B$ = "  hello" THEN PRINT "OK: RTRIM$"
B$ = TRIM$("x")
IF B$ = "x" THEN PRINT "OK: TRIM$ single"
PRINT "TRIM test done."
