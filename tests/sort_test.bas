REM Test SORT arr [, mode]
PRINT "Testing SORT..."
DIM A(2)
A(0) = 30 : A(1) = 10 : A(2) = 20
SORT A
IF A(0) = 10 AND A(1) = 20 AND A(2) = 30 THEN PRINT "OK: SORT asc"
SORT A, -1
IF A(0) = 30 AND A(1) = 20 AND A(2) = 10 THEN PRINT "OK: SORT desc"
DIM B$(2)
B$(0) = "z" : B$(1) = "a" : B$(2) = "m"
SORT B$
IF B$(0) = "a" AND B$(1) = "m" AND B$(2) = "z" THEN PRINT "OK: SORT string"
PRINT "SORT test done."
