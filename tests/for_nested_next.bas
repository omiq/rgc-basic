10 REM Nested FOR/NEXT: inner loop must keep outer frame (regression NEXT without FOR)
20 FOR Y=1 TO 2
30 FOR C=0 TO 1
40 REM
50 NEXT C
60 NEXT Y
70 PRINT "OK: nested FOR"
