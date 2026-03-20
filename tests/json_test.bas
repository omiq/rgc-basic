1 REM Test JSON$ path extraction
2 REM Use CHR$(34) for quote in strings
3 PRINT "Testing JSON$..."
4 Q$ = CHR$(34)
5 J$ = "{" + Q$ + "name" + Q$ + ":" + Q$ + "John" + Q$ + "," + Q$ + "age" + Q$ + ":30," + Q$ + "tags" + Q$ + ":[" + Q$ + "a" + Q$ + "," + Q$ + "b" + Q$ + "]}"
6 IF JSON$(J$, "name") = "John" THEN PRINT "OK: JSON$ name"
7 IF JSON$(J$, "age") = "30" THEN PRINT "OK: JSON$ number"
8 IF JSON$(J$, "tags[0]") = "a" THEN PRINT "OK: JSON$ array"
9 IF JSON$(J$, "tags[1]") = "b" THEN PRINT "OK: JSON$ array index"
10 J2$ = "{" + Q$ + "x" + Q$ + ":{" + Q$ + "y" + Q$ + ":" + Q$ + "nested" + Q$ + "}}"
11 IF JSON$(J2$, "x.y") = "nested" THEN PRINT "OK: JSON$ nested"
12 IF JSON$(J$, "missing") = "" THEN PRINT "OK: JSON$ missing key"
13 PRINT "JSON$ test done."
