10 REM INSTR case-insensitive optional 4th arg (non-zero = ignore case)
20 A$ = "Hello World"
30 IF INSTR(A$, "world", 1, 1) <> 7 THEN PRINT "FAIL1": END
40 IF INSTR(A$, "WORLD", 1, 1) <> 7 THEN PRINT "FAIL2": END
50 IF INSTR(A$, "world", 1, 0) <> 0 THEN PRINT "FAIL3": END
60 IF INSTR(A$, "Wo", 1, 1) <> 7 THEN PRINT "FAIL4": END
70 PRINT "INSTR_CI_OK"
80 END
