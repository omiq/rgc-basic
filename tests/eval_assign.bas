10 REM EVAL string "var=expr" must assign (not compare as expression)
20 A=10
30 X=EVAL("A=A+10")
40 IF A<>20 THEN PRINT "FAIL: A expected 20": END
50 IF X<>20 THEN PRINT "FAIL: EVAL return expected 20": END
60 PRINT "OK: EVAL assign"
