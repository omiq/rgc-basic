10 REM bigstring: copy-on-write semantics — B$/C$ keep original after A$ reassign
20 A$ = "hello"
30 B$ = A$
40 C$ = A$
50 A$ = "x"
60 IF B$ <> "hello" THEN PRINT "FAIL B$=";B$: GOTO 200
70 IF C$ <> "hello" THEN PRINT "FAIL C$=";C$: GOTO 200
80 IF A$ <> "x" THEN PRINT "FAIL A$=";A$: GOTO 200
90 PRINT "OK bigstring_refcount"
100 END
200 PRINT "FAIL bigstring_refcount"
