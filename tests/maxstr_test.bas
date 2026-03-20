REM Test string length limit: default 4096, #OPTION maxstr 255 for C64
REM Run: ./basic tests/maxstr_test.bas
PRINT "Testing default max string length..."
A$ = STRING$(100, "X")
IF LEN(A$) = 100 THEN PRINT "OK: STRING$(100) = 100 chars"
A$ = STRING$(500, "Y")
IF LEN(A$) = 500 THEN PRINT "OK: STRING$(500) = 500 chars"
A$ = STRING$(3000, "Z")
IF LEN(A$) = 3000 THEN PRINT "OK: STRING$(3000) = 3000 chars"
PRINT "Default maxstr test passed."
