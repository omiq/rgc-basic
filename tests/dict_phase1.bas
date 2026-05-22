1 REM DICT Phase 1: slot infra + scalar set/get
2 Q$ = CHR$(34)
3 PRINT "Testing DICTNEW / DICTFREE..."
10 H = DICTNEW()
11 IF H >= 0 AND H < 16 THEN PRINT "OK: DICTNEW returns valid slot"
20 DICTFREE H
21 PRINT "OK: DICTFREE returned"
30 DICTFREE H
31 PRINT "OK: DICTFREE is idempotent"
40 DICTFREE 999
41 PRINT "OK: DICTFREE out-of-range no error"
50 PRINT
60 PRINT "Testing DICTSET / DICTGET$..."
70 H = DICTNEW()
80 DICTSET H, "name", "Alice"
81 IF DICTGET$(H, "name") = "Alice" THEN PRINT "OK: string round-trip"
90 DICTSET H, "name", "Bob"
91 IF DICTGET$(H, "name") = "Bob" THEN PRINT "OK: string replace"
100 IF DICTGET$(H, "missing") = "" THEN PRINT "OK: missing key returns empty"
110 PRINT
120 PRINT "Testing DICTSET numbers..."
130 DICTSET H, "n", 42
140 IF DICTGETN(H, "n") = 42 THEN PRINT "OK: integer"
150 DICTSET H, "f", 3.5
160 IF DICTGETN(H, "f") > 3.4 AND DICTGETN(H, "f") < 3.6 THEN PRINT "OK: float"
170 DICTSET H, "neg", -7
180 IF DICTGETN(H, "neg") = -7 THEN PRINT "OK: negative"
190 DICTSET H, "big", 12345678
200 IF DICTGETN(H, "big") = 12345678 THEN PRINT "OK: large int no precision loss"
210 IF DICTGET$(H, "n") = "42" THEN PRINT "OK: number coerces to %lld string"
220 PRINT
230 PRINT "Testing DICTSETBOOL / DICTGETBOOL..."
240 DICTSETBOOL H, "ok", 1
250 IF DICTGETBOOL(H, "ok") = 1 THEN PRINT "OK: bool true"
260 DICTSETBOOL H, "ok", 0
270 IF DICTGETBOOL(H, "ok") = 0 THEN PRINT "OK: bool false"
280 DICTSETBOOL H, "ok", -1
290 IF DICTGETBOOL(H, "ok") = 1 THEN PRINT "OK: nonzero -> true"
300 IF DICTGETBOOL(H, "missing") = 0 THEN PRINT "OK: missing -> 0"
310 IF DICTGETBOOL(H, "n") = 0 THEN PRINT "OK: number isn't bool"
320 PRINT
330 PRINT "Testing DICTSETNULL / DICTHAS..."
340 DICTSETNULL H, "u"
350 IF DICTHAS(H, "u") = 1 THEN PRINT "OK: HAS detects explicit null"
360 IF DICTHAS(H, "missing") = 0 THEN PRINT "OK: HAS=0 for missing"
370 IF DICTHAS(H, "n") = 1 THEN PRINT "OK: HAS=1 for present number"
380 PRINT
390 PRINT "Testing DICTTYPE$..."
400 IF DICTTYPE$(H, "name") = "string" THEN PRINT "OK: type string"
410 IF DICTTYPE$(H, "n") = "number" THEN PRINT "OK: type number"
420 IF DICTTYPE$(H, "ok") = "bool" THEN PRINT "OK: type bool"
430 IF DICTTYPE$(H, "u") = "null" THEN PRINT "OK: type null"
440 IF DICTTYPE$(H, "missing") = "" THEN PRINT "OK: type missing empty"
450 PRINT
460 PRINT "Testing DICTLEN / DICTKEY$..."
470 H2 = DICTNEW()
480 DICTSET H2, "first", 1
490 DICTSET H2, "second", 2
500 DICTSET H2, "third", 3
510 IF DICTLEN(H2, "") = 3 THEN PRINT "OK: DICTLEN root = 3"
520 IF DICTKEY$(H2, "", 0) = "first" THEN PRINT "OK: DICTKEY[0] = first (insertion order)"
530 IF DICTKEY$(H2, "", 1) = "second" THEN PRINT "OK: DICTKEY[1] = second"
540 IF DICTKEY$(H2, "", 2) = "third" THEN PRINT "OK: DICTKEY[2] = third"
550 IF DICTKEY$(H2, "", 99) = "" THEN PRINT "OK: out-of-range key returns empty"
560 PRINT
570 PRINT "Testing use-after-free..."
580 H3 = DICTNEW()
590 DICTSET H3, "x", "alive"
600 DICTFREE H3
610 IF DICTGET$(H3, "x") = "" THEN PRINT "OK: read after free returns empty"
620 IF JSONSTATUS() = 4 THEN PRINT "OK: JSONSTATUS=4 after use-after-free"
630 DICTSET H3, "y", "noop"
640 PRINT "OK: write after free is no-op (no crash)"
650 PRINT
660 PRINT "Testing slot exhaustion..."
670 DIM SLOTS(20)
680 FOR I = 0 TO 15
690 SLOTS(I) = DICTNEW()
700 NEXT
710 OVER = DICTNEW()
720 IF OVER = -1 THEN PRINT "OK: 17th allocation returns -1"
730 FOR I = 0 TO 15
740 DICTFREE SLOTS(I)
750 NEXT
760 PRINT "OK: cleanup"
770 DICTFREE H
780 DICTFREE H2
799 PRINT "Phase 1 test done."
