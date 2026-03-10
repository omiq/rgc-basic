REM Regression tests for implicit LET on chained statements

REM Case 1: two assignments and a REM on one line
LB$="X": WT$=CHR$(5): REM LIGHT BLUE, WHITE

REM Case 2: array assignment then REM
DIM A(3)
A(1)=42: REM ARRAY ASSIGN

REM Case 3: mixed numeric and string assigns
X=10: S$="HELLO": REM MIXED

PRINT "LB$=";LB$
PRINT "WT$=";WT$
PRINT "A(1)=";A(1)
PRINT "X=";X
PRINT "S$=";S$

END

