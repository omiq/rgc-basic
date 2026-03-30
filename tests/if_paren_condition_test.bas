REM IF (relational OR relational) THEN — parens must parse as boolean, not eval_expr
J = 1
F = 1
A$ = " "
SF = 0
PX = 10
PY = 10
IF (J=F OR A$=" ") AND SF=0 THEN PRINT "OK1"
IF (J=F OR A$=" ") AND SF=0 THEN SX=PX:SY=PY-8:SF=1
IF SF=1 THEN PRINT "OK2"
END
