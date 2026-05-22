1 REM MAP Phase 2: path walker + nested + arrays
2 PRINT "Testing nested object paths..."
10 H = MAPNEW()
20 MAPSET H, "a.b.c", 7
30 IF MAPGETN(H, "a.b.c") = 7 THEN PRINT "OK: deep auto-vivify get"
40 IF MAPTYPE$(H, "a") = "object" THEN PRINT "OK: vivified a is object"
50 IF MAPTYPE$(H, "a.b") = "object" THEN PRINT "OK: vivified a.b is object"
60 IF MAPTYPE$(H, "a.b.c") = "number" THEN PRINT "OK: leaf is number"
70 IF MAPLEN(H, "a") = 1 THEN PRINT "OK: MAPLEN at nested object"
80 IF MAPKEY$(H, "a.b", 0) = "c" THEN PRINT "OK: MAPKEY$ on nested object"
90 MAPFREE H
100 PRINT
110 PRINT "Testing arrays..."
120 H = MAPNEW()
130 MAPSET H, "items[0]", "first"
140 MAPSET H, "items[1]", "second"
150 IF MAPGET$(H, "items[0]") = "first" THEN PRINT "OK: array elem 0"
160 IF MAPGET$(H, "items[1]") = "second" THEN PRINT "OK: array elem 1"
170 IF MAPLEN(H, "items") = 2 THEN PRINT "OK: MAPLEN array"
180 IF MAPTYPE$(H, "items") = "array" THEN PRINT "OK: type array"
190 MAPFREE H
200 PRINT
210 PRINT "Testing sparse array fill..."
220 H = MAPNEW()
230 MAPSET H, "items[3]", "d"
240 IF MAPLEN(H, "items") = 4 THEN PRINT "OK: sparse fills to length 4"
250 IF MAPTYPE$(H, "items[0]") = "null" THEN PRINT "OK: gap [0] is null"
260 IF MAPTYPE$(H, "items[1]") = "null" THEN PRINT "OK: gap [1] is null"
270 IF MAPTYPE$(H, "items[2]") = "null" THEN PRINT "OK: gap [2] is null"
280 IF MAPGET$(H, "items[3]") = "d" THEN PRINT "OK: value at end"
290 MAPFREE H
300 PRINT
310 PRINT "Testing mixed object+array..."
320 H = MAPNEW()
330 MAPSET H, "users[0].name", "alice"
340 MAPSET H, "users[0].age", 30
350 MAPSET H, "users[1].name", "bob"
360 IF MAPGET$(H, "users[0].name") = "alice" THEN PRINT "OK: mixed user[0].name"
370 IF MAPGETN(H, "users[0].age") = 30 THEN PRINT "OK: mixed user[0].age"
380 IF MAPGET$(H, "users[1].name") = "bob" THEN PRINT "OK: mixed user[1].name"
390 IF MAPLEN(H, "users") = 2 THEN PRINT "OK: users array len"
400 IF MAPLEN(H, "users[0]") = 2 THEN PRINT "OK: users[0] object len"
410 MAPFREE H
420 PRINT
430 PRINT "Testing MAPDEL..."
440 H = MAPNEW()
450 MAPSET H, "a", 1
460 MAPSET H, "b", 2
470 MAPSET H, "c", 3
480 MAPDEL H, "b"
490 IF MAPHAS(H, "b") = 0 THEN PRINT "OK: deleted key gone"
500 IF MAPHAS(H, "a") = 1 AND MAPHAS(H, "c") = 1 THEN PRINT "OK: siblings still present"
510 IF MAPLEN(H, "") = 2 THEN PRINT "OK: root len after del"
520 IF MAPKEY$(H, "", 0) = "a" THEN PRINT "OK: first key preserved order"
530 IF MAPKEY$(H, "", 1) = "c" THEN PRINT "OK: second key shifted"
540 MAPDEL H, "missing"
550 IF MAPLEN(H, "") = 2 THEN PRINT "OK: MAPDEL on missing is no-op"
560 MAPFREE H
570 PRINT
580 PRINT "Testing array MAPDEL..."
590 H = MAPNEW()
600 MAPSET H, "xs[0]", "a"
610 MAPSET H, "xs[1]", "b"
620 MAPSET H, "xs[2]", "c"
630 MAPDEL H, "xs[1]"
640 IF MAPLEN(H, "xs") = 2 THEN PRINT "OK: array shrunk by 1"
650 IF MAPGET$(H, "xs[0]") = "a" THEN PRINT "OK: xs[0] kept"
660 IF MAPGET$(H, "xs[1]") = "c" THEN PRINT "OK: xs[1] is former xs[2]"
670 MAPFREE H
680 PRINT
690 PRINT "Testing descent through scalar (error)..."
700 H = MAPNEW()
710 MAPSET H, "a", "scalar"
720 MAPSET H, "a.b", 1
730 IF JSONSTATUS() = 2 THEN PRINT "OK: scalar descent sets JSONSTATUS=2"
740 IF MAPGET$(H, "a") = "scalar" THEN PRINT "OK: original scalar preserved"
750 IF MAPHAS(H, "a.b") = 0 THEN PRINT "OK: failed write left no a.b"
760 MAPFREE H
770 PRINT
780 PRINT "Testing root as array..."
790 H = MAPNEW()
800 MAPSET H, "[0]", "first"
810 MAPSET H, "[1]", "second"
820 IF MAPTYPE$(H, "") = "array" THEN PRINT "OK: root is array"
830 IF MAPLEN(H, "") = 2 THEN PRINT "OK: array root len"
840 IF MAPGET$(H, "[0]") = "first" THEN PRINT "OK: array root [0]"
850 MAPFREE H
860 PRINT
870 PRINT "Testing chained nested writes..."
880 H = MAPNEW()
890 MAPSET H, "a.b.c.d.e", "deep"
900 IF MAPGET$(H, "a.b.c.d.e") = "deep" THEN PRINT "OK: 5-deep auto-vivify"
910 IF MAPLEN(H, "a.b.c.d") = 1 THEN PRINT "OK: intermediate object created"
920 MAPFREE H
999 PRINT "Phase 2 test done."
