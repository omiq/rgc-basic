1 REM Test EVAL(expr$) - evaluate expression from string
2 PRINT "Testing EVAL..."
3 IF EVAL("2+3") = 5 THEN PRINT "OK: EVAL numeric"
4 IF EVAL("10*2") = 20 THEN PRINT "OK: EVAL multiply"
5 A = 42
6 IF EVAL("A") = 42 THEN PRINT "OK: EVAL variable"
7 B$ = "hello"
8 IF EVAL("B$") = "hello" THEN PRINT "OK: EVAL string var"
9 IF EVAL("LEN(B$)") = 5 THEN PRINT "OK: EVAL function"
10 Q$ = CHR$(34)
11 E$ = "B$ + " + Q$ + " world" + Q$
12 IF EVAL(E$) = "hello world" THEN PRINT "OK: EVAL concat"
13 J$ = "{" + Q$ + "x" + Q$ + ":99}"
14 E2$ = "JSON$(J$, " + Q$ + "x" + Q$ + ")"
15 IF VAL(EVAL(E2$)) = 99 THEN PRINT "OK: EVAL JSON$"
16 PRINT "EVAL test done."
