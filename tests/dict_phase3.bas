1 REM DICT Phase 3: serialise, load, DICTPUSH, DICTUNPACK
2 Q$ = CHR$(34)
3 PRINT "Testing JSON$(handle) overload..."
10 H = DICTNEW()
20 IF JSON$(H) = "{}" THEN PRINT "OK: empty map -> {}"
30 DICTSET H, "name", "Alice"
40 IF JSON$(H) = "{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$ + "}" THEN PRINT "OK: single string"
50 DICTSET H, "age", 30
60 IF JSON$(H) = "{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$ + "," + Q$ + "age" + Q$ + ":30}" THEN PRINT "OK: insertion order in JSON"
70 DICTSETBOOL H, "ok", 1
80 IF INSTR(JSON$(H), Q$ + "ok" + Q$ + ":true") > 0 THEN PRINT "OK: bool true serialised"
90 DICTSETBOOL H, "bad", 0
100 IF INSTR(JSON$(H), Q$ + "bad" + Q$ + ":false") > 0 THEN PRINT "OK: bool false serialised"
110 DICTSETNULL H, "u"
120 IF INSTR(JSON$(H), Q$ + "u" + Q$ + ":null") > 0 THEN PRINT "OK: null serialised"
130 DICTFREE H
140 PRINT
150 PRINT "Testing JSON$(handle) with nested..."
160 H = DICTNEW()
170 DICTSET H, "user.name", "Bob"
180 DICTSET H, "user.age", 25
190 IF INSTR(JSON$(H), Q$ + "user" + Q$ + ":{") > 0 THEN PRINT "OK: nested object serialised"
200 DICTSET H, "tags[0]", "a"
210 DICTSET H, "tags[1]", "b"
220 IF INSTR(JSON$(H), Q$ + "tags" + Q$ + ":[" + Q$ + "a" + Q$ + "," + Q$ + "b" + Q$ + "]") > 0 THEN PRINT "OK: array serialised"
230 DICTFREE H
240 PRINT
250 PRINT "Testing DICTLOAD..."
260 H = DICTLOAD("{" + Q$ + "n" + Q$ + ":42," + Q$ + "s" + Q$ + ":" + Q$ + "hi" + Q$ + "}")
270 IF H >= 0 THEN PRINT "OK: DICTLOAD returns valid handle"
280 IF DICTGETN(H, "n") = 42 THEN PRINT "OK: loaded number"
290 IF DICTGET$(H, "s") = "hi" THEN PRINT "OK: loaded string"
300 DICTFREE H
310 PRINT
320 PRINT "Testing DICTLOAD nested..."
330 J$ = "{" + Q$ + "user" + Q$ + ":{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$ + "}," + Q$ + "tags" + Q$ + ":[" + Q$ + "x" + Q$ + "," + Q$ + "y" + Q$ + "]}"
340 H = DICTLOAD(J$)
350 IF DICTGET$(H, "user.name") = "Alice" THEN PRINT "OK: loaded nested user.name"
360 IF DICTGET$(H, "tags[0]") = "x" THEN PRINT "OK: loaded tags[0]"
370 IF DICTGET$(H, "tags[1]") = "y" THEN PRINT "OK: loaded tags[1]"
380 IF DICTLEN(H, "tags") = 2 THEN PRINT "OK: loaded tags length"
390 DICTFREE H
400 PRINT
410 PRINT "Testing JSON$/DICTLOAD round-trip..."
420 H1 = DICTNEW()
430 DICTSET H1, "a", 1
440 DICTSET H1, "b", "two"
450 DICTSET H1, "c[0]", 10
460 DICTSET H1, "c[1]", 20
470 S$ = JSON$(H1)
480 H2 = DICTLOAD(S$)
490 IF JSON$(H2) = S$ THEN PRINT "OK: round-trip preserves structure"
500 DICTFREE H1
510 DICTFREE H2
520 PRINT
530 PRINT "Testing DICTPUSH..."
540 H = DICTNEW()
550 DICTPUSH H, "tags", "first"
560 IF DICTLEN(H, "tags") = 1 THEN PRINT "OK: PUSH to missing auto-vivifies array"
570 IF DICTGET$(H, "tags[0]") = "first" THEN PRINT "OK: PUSH first elem"
580 DICTPUSH H, "tags", "second"
590 IF DICTLEN(H, "tags") = 2 THEN PRINT "OK: PUSH appends"
600 IF DICTGET$(H, "tags[1]") = "second" THEN PRINT "OK: PUSH second elem"
610 DICTPUSH H, "tags", 42
620 IF DICTGETN(H, "tags[2]") = 42 THEN PRINT "OK: PUSH mixed type"
630 DICTFREE H
640 PRINT
650 PRINT "Testing DICTPUSH type error..."
660 H = DICTNEW()
670 DICTSET H, "x", "scalar"
680 DICTPUSH H, "x", "boom"
690 IF JSONSTATUS() = 2 THEN PRINT "OK: PUSH on non-array sets JSONSTATUS=2"
700 IF DICTGET$(H, "x") = "scalar" THEN PRINT "OK: PUSH on non-array preserves value"
710 DICTFREE H
720 PRINT
730 PRINT "Testing DICTUNPACK + FOREACH..."
740 H = DICTLOAD("[" + Q$ + "a" + Q$ + "," + Q$ + "b" + Q$ + "," + Q$ + "c" + Q$ + "]")
750 DIM ITEMS$(0)
760 DICTUNPACK H, "" INTO ITEMS$
770 COUNT = 0
780 FOREACH X$ IN ITEMS$
790 COUNT = COUNT + 1
800 NEXT
810 IF COUNT = 3 THEN PRINT "OK: DICTUNPACK + FOREACH visits all"
820 IF ITEMS$(0) = Q$ + "a" + Q$ THEN PRINT "OK: items[0] JSON-quoted"
830 DICTFREE H
840 PRINT
850 PRINT "Testing DICTUNPACK on path..."
860 H = DICTLOAD("{" + Q$ + "items" + Q$ + ":[1,2,3,4]}")
870 DIM XS$(0)
880 DICTUNPACK H, "items" INTO XS$
890 IF DICTLEN(H, "items") = 4 THEN PRINT "OK: source preserved"
900 COUNT = 0
910 FOREACH X$ IN XS$
920 COUNT = COUNT + 1
930 NEXT
940 IF COUNT = 4 THEN PRINT "OK: unpacked 4 elements"
950 IF XS$(0) = "1" THEN PRINT "OK: numeric element 0"
960 IF XS$(3) = "4" THEN PRINT "OK: numeric element 3"
970 DICTFREE H
999 PRINT "Phase 3 test done."
