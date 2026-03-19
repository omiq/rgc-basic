REM Test IF/ELSE/END IF (numberless)
IF ARGC() = 0 THEN
    PRINT "THEN branch: no args"
ELSE 
    PRINT "ELSE branch: has args"; ARG$(1)
END IF
PRINT "Done"
