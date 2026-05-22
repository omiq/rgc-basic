1 REM JSONUNPACK statement: resize a string array to match a JSON array
2 Q$ = CHR$(34)
3 PRINT "Testing JSONUNPACK + FOREACH..."
10 DIM ITEMS$(0)
20 J$ = "{" + Q$ + "items" + Q$ + ":[" + Q$ + "a" + Q$ + "," + Q$ + "b" + Q$ + "," + Q$ + "c" + Q$ + "]}"
30 JSONUNPACK J$, "items" INTO ITEMS$
40 COUNT = 0
50 FOREACH X$ IN ITEMS$
60 COUNT = COUNT + 1
70 NEXT
80 IF COUNT = 3 THEN PRINT "OK: FOREACH visits exact JSON count"
90 IF ITEMS$(0) = Q$ + "a" + Q$ THEN PRINT "OK: element 0 is JSON-quoted"
100 IF ITEMS$(2) = Q$ + "c" + Q$ THEN PRINT "OK: element 2"
110 PRINT
120 PRINT "Testing JSONUNPACK on empty array..."
130 DIM EMPTYARR$(0)
140 JSONUNPACK "[]", "" INTO EMPTYARR$
150 COUNT = 0
160 FOREACH X$ IN EMPTYARR$
170 COUNT = COUNT + 1
180 NEXT
190 IF COUNT = 0 THEN PRINT "OK: empty array yields zero iterations"
200 PRINT
210 PRINT "Testing JSONUNPACK with object elements + nested JSON$..."
220 DIM USERS$(0)
230 U$ = "[" + "{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$ + "}" + "," + "{" + Q$ + "name" + Q$ + ":" + Q$ + "Bob" + Q$ + "}" + "]"
240 JSONUNPACK U$, "" INTO USERS$
250 NAMES$ = ""
260 FOREACH USR$ IN USERS$
270 NAMES$ = NAMES$ + JSON$(USR$, "name") + ","
280 NEXT
290 IF NAMES$ = "Alice,Bob," THEN PRINT "OK: nested JSON$ on each element"
300 PRINT
310 PRINT "Testing JSONUNPACK resize (shrink)..."
320 DIM BIG$(100)
330 JSONUNPACK J$, "items" INTO BIG$
340 COUNT = 0
350 FOREACH X$ IN BIG$
360 COUNT = COUNT + 1
370 NEXT
380 IF COUNT = 3 THEN PRINT "OK: DIM(100) shrank to 3 to match JSON"
399 PRINT "JSONUNPACK test done."
