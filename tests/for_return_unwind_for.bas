10 REM RETURN must discard FOR frames started inside the subroutine (CBM-style)
20 FOR I=1 TO 2
30 GOSUB 100
40 NEXT I
50 PRINT "OK: FOR survives GOSUB after inner FOR"
60 END
100 FOR J=1 TO 1
110 NEXT J
120 RETURN
