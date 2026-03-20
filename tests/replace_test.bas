REM Test REPLACE(str$, find$, repl$)
PRINT "Testing REPLACE..."
A$ = REPLACE("yes or no", "yes", "no")
IF A$ = "no or no" THEN PRINT "OK: REPLACE yes->no"
A$ = REPLACE("aaa", "a", "b")
IF A$ = "bbb" THEN PRINT "OK: REPLACE all"
A$ = REPLACE("hello", "x", "y")
IF A$ = "hello" THEN PRINT "OK: REPLACE no match"
PRINT "REPLACE test done."
