REM Test TRIM$, LTRIM$, RTRIM$
PRINT "Testing TRIM..."
A$ = "  hello  "
IF TRIM$(A$) = "hello" THEN PRINT "OK: TRIM$"
IF LTRIM$(A$) = "hello  " THEN PRINT "OK: LTRIM$"
IF RTRIM$(A$) = "  hello" THEN PRINT "OK: RTRIM$"
IF TRIM$("x") = "x" THEN PRINT "OK: TRIM$ single"
PRINT "TRIM test done."
