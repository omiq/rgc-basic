10 REM Nested FOR/NEXT: inner loop must keep outer frame (regression NEXT without FOR)
20 FOR Y=1 TO 2
30 FOR C=0 TO 1
40 REM
50 NEXT C
60 NEXT Y
70 PRINT "OK: nested FOR"
80 REM Explicit NEXT names + STEP (regression: NEXT must match inner FOR even if frame name empty)
90 FOR Y=1 TO 2 STEP 1
100 FOR C=0 TO 1
110 REM
120 NEXT C
130 NEXT Y
140 PRINT "OK: explicit NEXT + STEP"
