10 REM JSON$ returns raw text for object/array root values
20 Q$ = CHR$(34)
30 J3$ = "{" + Q$ + "obj" + Q$ + ":{" + Q$ + "k" + Q$ + ":1}" + "}"
40 V$ = JSON$(J3$, "obj")
50 IF INSTR(V$, "{") = 1 THEN PRINT "OK: JSON$ object value"
60 J$ = "{" + Q$ + "name" + Q$ + ":" + Q$ + "John" + Q$ + "," + Q$ + "tags" + Q$ + ":[" + Q$ + "a" + Q$ + "," + Q$ + "b" + Q$ + "]}"
70 V2$ = JSON$(J$, "tags")
80 IF INSTR(V2$, "[") = 1 THEN PRINT "OK: JSON$ array value"
90 END
