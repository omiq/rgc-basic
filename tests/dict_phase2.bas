1 REM DICT Phase 2: path walker + nested + arrays
2 PRINT "Testing nested object paths..."
10 H = DICTNEW()
20 DICTSET H, "a.b.c", 7
30 IF DICTGETN(H, "a.b.c") = 7 THEN PRINT "OK: deep auto-vivify get"
40 IF DICTTYPE$(H, "a") = "object" THEN PRINT "OK: vivified a is object"
50 IF DICTTYPE$(H, "a.b") = "object" THEN PRINT "OK: vivified a.b is object"
60 IF DICTTYPE$(H, "a.b.c") = "number" THEN PRINT "OK: leaf is number"
70 IF DICTLEN(H, "a") = 1 THEN PRINT "OK: DICTLEN at nested object"
80 IF DICTKEY$(H, "a.b", 0) = "c" THEN PRINT "OK: DICTKEY$ on nested object"
90 DICTFREE H
100 PRINT
110 PRINT "Testing arrays..."
120 H = DICTNEW()
130 DICTSET H, "items[0]", "first"
140 DICTSET H, "items[1]", "second"
150 IF DICTGET$(H, "items[0]") = "first" THEN PRINT "OK: array elem 0"
160 IF DICTGET$(H, "items[1]") = "second" THEN PRINT "OK: array elem 1"
170 IF DICTLEN(H, "items") = 2 THEN PRINT "OK: DICTLEN array"
180 IF DICTTYPE$(H, "items") = "array" THEN PRINT "OK: type array"
190 DICTFREE H
200 PRINT
210 PRINT "Testing sparse array fill..."
220 H = DICTNEW()
230 DICTSET H, "items[3]", "d"
240 IF DICTLEN(H, "items") = 4 THEN PRINT "OK: sparse fills to length 4"
250 IF DICTTYPE$(H, "items[0]") = "null" THEN PRINT "OK: gap [0] is null"
260 IF DICTTYPE$(H, "items[1]") = "null" THEN PRINT "OK: gap [1] is null"
270 IF DICTTYPE$(H, "items[2]") = "null" THEN PRINT "OK: gap [2] is null"
280 IF DICTGET$(H, "items[3]") = "d" THEN PRINT "OK: value at end"
290 DICTFREE H
300 PRINT
310 PRINT "Testing mixed object+array..."
320 H = DICTNEW()
330 DICTSET H, "users[0].name", "alice"
340 DICTSET H, "users[0].age", 30
350 DICTSET H, "users[1].name", "bob"
360 IF DICTGET$(H, "users[0].name") = "alice" THEN PRINT "OK: mixed user[0].name"
370 IF DICTGETN(H, "users[0].age") = 30 THEN PRINT "OK: mixed user[0].age"
380 IF DICTGET$(H, "users[1].name") = "bob" THEN PRINT "OK: mixed user[1].name"
390 IF DICTLEN(H, "users") = 2 THEN PRINT "OK: users array len"
400 IF DICTLEN(H, "users[0]") = 2 THEN PRINT "OK: users[0] object len"
410 DICTFREE H
420 PRINT
430 PRINT "Testing DICTDEL..."
440 H = DICTNEW()
450 DICTSET H, "a", 1
460 DICTSET H, "b", 2
470 DICTSET H, "c", 3
480 DICTDEL H, "b"
490 IF DICTHAS(H, "b") = 0 THEN PRINT "OK: deleted key gone"
500 IF DICTHAS(H, "a") = 1 AND DICTHAS(H, "c") = 1 THEN PRINT "OK: siblings still present"
510 IF DICTLEN(H, "") = 2 THEN PRINT "OK: root len after del"
520 IF DICTKEY$(H, "", 0) = "a" THEN PRINT "OK: first key preserved order"
530 IF DICTKEY$(H, "", 1) = "c" THEN PRINT "OK: second key shifted"
540 DICTDEL H, "missing"
550 IF DICTLEN(H, "") = 2 THEN PRINT "OK: DICTDEL on missing is no-op"
560 DICTFREE H
570 PRINT
580 PRINT "Testing array DICTDEL..."
590 H = DICTNEW()
600 DICTSET H, "xs[0]", "a"
610 DICTSET H, "xs[1]", "b"
620 DICTSET H, "xs[2]", "c"
630 DICTDEL H, "xs[1]"
640 IF DICTLEN(H, "xs") = 2 THEN PRINT "OK: array shrunk by 1"
650 IF DICTGET$(H, "xs[0]") = "a" THEN PRINT "OK: xs[0] kept"
660 IF DICTGET$(H, "xs[1]") = "c" THEN PRINT "OK: xs[1] is former xs[2]"
670 DICTFREE H
680 PRINT
690 PRINT "Testing descent through scalar (error)..."
700 H = DICTNEW()
710 DICTSET H, "a", "scalar"
720 DICTSET H, "a.b", 1
730 IF JSONSTATUS() = 2 THEN PRINT "OK: scalar descent sets JSONSTATUS=2"
740 IF DICTGET$(H, "a") = "scalar" THEN PRINT "OK: original scalar preserved"
750 IF DICTHAS(H, "a.b") = 0 THEN PRINT "OK: failed write left no a.b"
760 DICTFREE H
770 PRINT
780 PRINT "Testing root as array..."
790 H = DICTNEW()
800 DICTSET H, "[0]", "first"
810 DICTSET H, "[1]", "second"
820 IF DICTTYPE$(H, "") = "array" THEN PRINT "OK: root is array"
830 IF DICTLEN(H, "") = 2 THEN PRINT "OK: array root len"
840 IF DICTGET$(H, "[0]") = "first" THEN PRINT "OK: array root [0]"
850 DICTFREE H
860 PRINT
870 PRINT "Testing chained nested writes..."
880 H = DICTNEW()
890 DICTSET H, "a.b.c.d.e", "deep"
900 IF DICTGET$(H, "a.b.c.d.e") = "deep" THEN PRINT "OK: 5-deep auto-vivify"
910 IF DICTLEN(H, "a.b.c.d") = 1 THEN PRINT "OK: intermediate object created"
920 DICTFREE H
999 PRINT "Phase 2 test done."
