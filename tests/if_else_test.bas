10 REM Test IF/ELSE/END IF
20 IF ARGC() = 0 THEN
30     PRINT "THEN branch: no args"
40 ELSE 
50     PRINT "ELSE branch: has args"; ARG$(1)
60 END IF
70 PRINT "Done"
