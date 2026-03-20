REM Test SPLIT and JOIN
PRINT "Testing SPLIT..."
DIM A$(5)
SPLIT "a,b,c", "," INTO A$
IF A$(0) = "a" AND A$(1) = "b" AND A$(2) = "c" THEN PRINT "OK: SPLIT"
PRINT "Testing JOIN..."
JOIN A$, "|" INTO R$, 3
IF R$ = "a|b|c" THEN PRINT "OK: JOIN"
SPLIT "x,,y", "," INTO A$
IF A$(0) = "x" AND A$(1) = "" AND A$(2) = "y" THEN PRINT "OK: SPLIT empty field"
PRINT "SPLIT/JOIN test done."
