1 REM MAP Phase 1: slot infra + scalar set/get
2 Q$ = CHR$(34)
3 PRINT "Testing MAPNEW / MAPFREE..."
10 H = MAPNEW()
11 IF H >= 0 AND H < 16 THEN PRINT "OK: MAPNEW returns valid slot"
20 MAPFREE H
21 PRINT "OK: MAPFREE returned"
30 MAPFREE H
31 PRINT "OK: MAPFREE is idempotent"
40 MAPFREE 999
41 PRINT "OK: MAPFREE out-of-range no error"
50 PRINT
60 PRINT "Testing MAPSET / MAPGET$..."
70 H = MAPNEW()
80 MAPSET H, "name", "Alice"
81 IF MAPGET$(H, "name") = "Alice" THEN PRINT "OK: string round-trip"
90 MAPSET H, "name", "Bob"
91 IF MAPGET$(H, "name") = "Bob" THEN PRINT "OK: string replace"
100 IF MAPGET$(H, "missing") = "" THEN PRINT "OK: missing key returns empty"
110 PRINT
120 PRINT "Testing MAPSET numbers..."
130 MAPSET H, "n", 42
140 IF MAPGETN(H, "n") = 42 THEN PRINT "OK: integer"
150 MAPSET H, "f", 3.5
160 IF MAPGETN(H, "f") > 3.4 AND MAPGETN(H, "f") < 3.6 THEN PRINT "OK: float"
170 MAPSET H, "neg", -7
180 IF MAPGETN(H, "neg") = -7 THEN PRINT "OK: negative"
190 MAPSET H, "big", 12345678
200 IF MAPGETN(H, "big") = 12345678 THEN PRINT "OK: large int no precision loss"
210 IF MAPGET$(H, "n") = "42" THEN PRINT "OK: number coerces to %lld string"
220 PRINT
230 PRINT "Testing MAPSETBOOL / MAPGETBOOL..."
240 MAPSETBOOL H, "ok", 1
250 IF MAPGETBOOL(H, "ok") = 1 THEN PRINT "OK: bool true"
260 MAPSETBOOL H, "ok", 0
270 IF MAPGETBOOL(H, "ok") = 0 THEN PRINT "OK: bool false"
280 MAPSETBOOL H, "ok", -1
290 IF MAPGETBOOL(H, "ok") = 1 THEN PRINT "OK: nonzero -> true"
300 IF MAPGETBOOL(H, "missing") = 0 THEN PRINT "OK: missing -> 0"
310 IF MAPGETBOOL(H, "n") = 0 THEN PRINT "OK: number isn't bool"
320 PRINT
330 PRINT "Testing MAPSETNULL / MAPHAS..."
340 MAPSETNULL H, "u"
350 IF MAPHAS(H, "u") = 1 THEN PRINT "OK: HAS detects explicit null"
360 IF MAPHAS(H, "missing") = 0 THEN PRINT "OK: HAS=0 for missing"
370 IF MAPHAS(H, "n") = 1 THEN PRINT "OK: HAS=1 for present number"
380 PRINT
390 PRINT "Testing MAPTYPE$..."
400 IF MAPTYPE$(H, "name") = "string" THEN PRINT "OK: type string"
410 IF MAPTYPE$(H, "n") = "number" THEN PRINT "OK: type number"
420 IF MAPTYPE$(H, "ok") = "bool" THEN PRINT "OK: type bool"
430 IF MAPTYPE$(H, "u") = "null" THEN PRINT "OK: type null"
440 IF MAPTYPE$(H, "missing") = "" THEN PRINT "OK: type missing empty"
450 PRINT
460 PRINT "Testing MAPLEN / MAPKEY$..."
470 H2 = MAPNEW()
480 MAPSET H2, "first", 1
490 MAPSET H2, "second", 2
500 MAPSET H2, "third", 3
510 IF MAPLEN(H2, "") = 3 THEN PRINT "OK: MAPLEN root = 3"
520 IF MAPKEY$(H2, "", 0) = "first" THEN PRINT "OK: MAPKEY[0] = first (insertion order)"
530 IF MAPKEY$(H2, "", 1) = "second" THEN PRINT "OK: MAPKEY[1] = second"
540 IF MAPKEY$(H2, "", 2) = "third" THEN PRINT "OK: MAPKEY[2] = third"
550 IF MAPKEY$(H2, "", 99) = "" THEN PRINT "OK: out-of-range key returns empty"
560 PRINT
570 PRINT "Testing use-after-free..."
580 H3 = MAPNEW()
590 MAPSET H3, "x", "alive"
600 MAPFREE H3
610 IF MAPGET$(H3, "x") = "" THEN PRINT "OK: read after free returns empty"
620 IF JSONSTATUS() = 4 THEN PRINT "OK: JSONSTATUS=4 after use-after-free"
630 MAPSET H3, "y", "noop"
640 PRINT "OK: write after free is no-op (no crash)"
650 PRINT
660 PRINT "Testing slot exhaustion..."
670 DIM SLOTS(20)
680 FOR I = 0 TO 15
690 SLOTS(I) = MAPNEW()
700 NEXT
710 OVER = MAPNEW()
720 IF OVER = -1 THEN PRINT "OK: 17th allocation returns -1"
730 FOR I = 0 TO 15
740 MAPFREE SLOTS(I)
750 NEXT
760 PRINT "OK: cleanup"
770 MAPFREE H
780 MAPFREE H2
799 PRINT "Phase 1 test done."
