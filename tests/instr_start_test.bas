REM Test INSTR with optional start position
REM INSTR(source$, find$ [, start]) - 1-based index, 0 if not found
PRINT "Testing INSTR with start..."
A$ = "abcabcabc"
IF INSTR(A$,"a") = 1 THEN PRINT "OK: INSTR first a"
IF INSTR(A$,"a",2) = 4 THEN PRINT "OK: INSTR from pos 2"
IF INSTR(A$,"a",5) = 7 THEN PRINT "OK: INSTR from pos 5"
IF INSTR(A$,"x") = 0 THEN PRINT "OK: INSTR not found"
IF INSTR(A$,"a",10) = 0 THEN PRINT "OK: INSTR start past end"
PRINT "INSTR start test done."
