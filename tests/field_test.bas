REM Test FIELD$(str$, delim$, n) - get Nth field, 1-based
PRINT "Testing FIELD$..."
IF FIELD$("a,b,c", ",", 1) = "a" THEN PRINT "OK: field 1"
IF FIELD$("a,b,c", ",", 2) = "b" THEN PRINT "OK: field 2"
IF FIELD$("a,b,c", ",", 3) = "c" THEN PRINT "OK: field 3"
IF FIELD$("a,,b", ",", 2) = "" THEN PRINT "OK: empty field"
IF FIELD$("x", ",", 1) = "x" THEN PRINT "OK: single"
PRINT "FIELD$ test done."
