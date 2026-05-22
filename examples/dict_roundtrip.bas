10 REM dict_roundtrip: load JSON, mutate via MAP, serialise back.
20 REM
30 REM This is the recommended pattern for any non-trivial JSON
40 REM transformation. JSONPUT$ chains re-parse the whole string on
50 REM every call — fine for 2 or 3 fields, painful at 20. DICT holds
60 REM the structure in memory as a tree; mutations are in-place and
70 REM cheap; you pay the serialise cost exactly once at the end.
80 REM
90 Q$ = CHR$(34)
100 REM Suppose the input is an order coming in over HTTP$ or read
110 REM from a file. We define one inline here for the example.
120 SRC$ = "{"
130 SRC$ = SRC$ + Q$ + "id" + Q$ + ":1024"
140 SRC$ = SRC$ + "," + Q$ + "customer" + Q$ + ":" + Q$ + "Alice" + Q$
150 SRC$ = SRC$ + "," + Q$ + "items" + Q$ + ":["
160 SRC$ = SRC$ + "{" + Q$ + "sku" + Q$ + ":" + Q$ + "AAA" + Q$ + "," + Q$ + "qty" + Q$ + ":2}"
170 SRC$ = SRC$ + ",{" + Q$ + "sku" + Q$ + ":" + Q$ + "BBB" + Q$ + "," + Q$ + "qty" + Q$ + ":1}"
180 SRC$ = SRC$ + "]}"
190 PRINT "Input JSON:"
200 PRINT SRC$
210 PRINT
220 REM Parse into a map. DICTLOAD returns a slot handle, or -1 on a
230 REM parse error (check JSONSTATUS to disambiguate).
240 ORDER = DICTLOAD(SRC$)
250 IF ORDER < 0 THEN PRINT "Parse failed; JSONSTATUS="; JSONSTATUS() : END
260 REM Read fields by path.
270 PRINT "Customer: "; DICTGET$(ORDER, "customer")
280 PRINT "Item count: "; DICTLEN(ORDER, "items")
290 PRINT
300 REM Mutate: bump the qty on every item, then append a new line.
310 N = DICTLEN(ORDER, "items")
320 FOR I = 0 TO N - 1
330 PATH$ = "items[" + STR$(I) + "].qty"
340 OLD = DICTGETN(ORDER, PATH$)
350 DICTSET ORDER, PATH$, OLD + 1
360 NEXT
370 REM DICTPUSH auto-vivifies an array slot and appends. Here we add
380 REM a third item via a fresh sub-map serialised to a literal.
390 NEW$ = "{" + Q$ + "sku" + Q$ + ":" + Q$ + "CCC" + Q$ + "," + Q$ + "qty" + Q$ + ":5}"
400 DICTPUSH ORDER, "items", NEW$
410 REM Add a derived total field.
420 TOTAL = 0
430 FOR I = 0 TO DICTLEN(ORDER, "items") - 1
440 TOTAL = TOTAL + DICTGETN(ORDER, "items[" + STR$(I) + "].qty")
450 NEXT
460 DICTSET ORDER, "total_qty", TOTAL
470 REM Drop a field we don't want in the output.
480 DICTDEL ORDER, "customer"
490 REM Serialise. JSON$(handle) walks the tree exactly once.
500 PRINT "Transformed JSON:"
510 PRINT JSON$(ORDER)
520 PRINT
530 PRINT "Note: DICTPUSH stored the new line as a JSON string, not a"
540 PRINT "sub-map, so it serialises with its quotes escaped. To push"
550 PRINT "as a real nested object, set fields with DICTSET path-by-path:"
560 PRINT "  DICTSET ORDER, " + Q$ + "items[3].sku" + Q$ + ", " + Q$ + "DDD" + Q$
570 DICTFREE ORDER
