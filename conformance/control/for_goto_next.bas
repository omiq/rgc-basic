10 REM Conformance: forward GOTO within a FOR body onto the NEXT line.
20 REM Regression guard for wishlist 5b ("NEXT without FOR").
30 S = 0
40 FOR I = 1 TO 5
50 IF I > 0 THEN GOTO 70
60 PRINT "unreachable"
70 S = S + I : NEXT I
80 ASSERT S = 15, "FOR + forward GOTO into NEXT line sums 1..5"
90 REM nested case: GOTO into the inner NEXT line
100 T = 0
110 FOR A = 1 TO 3
120 FOR B = 1 TO 3
130 IF B > 0 THEN GOTO 150
140 PRINT "unreachable"
150 T = T + 1 : NEXT B : NEXT A
160 ASSERT T = 9, "nested FOR + GOTO into inner NEXT line counts 9"
170 PRINT "control/for_goto_next: all assertions passed"
180 END
