REM Test IF cond AND cond THEN (trek.bas line 5930 pattern)
REM Bug: eval_expr consumed AND as bitwise, leaving "=0 THEN" -> Missing THEN
X=13
Y=0
IF X=13 AND Y=0 THEN PRINT "OK1"
IF X=13 AND Y=1 THEN PRINT "BAD"
IF X<>13 OR Y=0 THEN PRINT "OK2"
PRINT "DONE"
