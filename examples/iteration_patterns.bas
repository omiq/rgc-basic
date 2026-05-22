10 REM iteration_patterns: three ways to walk a JSON structure.
20 REM
30 REM RGC-BASIC gives you a few iteration styles. Pick the one whose
40 REM cost matches the data — verbose-but-flexible for one-off scans,
50 REM cleaner sugar for repeated walks, DICT when you need both object
60 REM keys and array indices in the same traversal.
70 REM
80 Q$ = CHR$(34)
90 J$ = "{" + Q$ + "users" + Q$ + ":["
100 J$ = J$ + "{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$ + "," + Q$ + "age" + Q$ + ":30}"
110 J$ = J$ + ",{" + Q$ + "name" + Q$ + ":" + Q$ + "Bob" + Q$ + "," + Q$ + "age" + Q$ + ":25}"
120 J$ = J$ + ",{" + Q$ + "name" + Q$ + ":" + Q$ + "Carol" + Q$ + "," + Q$ + "age" + Q$ + ":42}"
130 J$ = J$ + "]}"
140 PRINT "Source: "; J$
150 PRINT
160 REM --- Pattern 1: FOR loop over an array using JSONLEN + path concat
170 REM
180 REM Works on any JSON string without extra setup. The cost is a
190 REM linear walk per JSON$ call, so for an N-element array this
200 REM scan is O(N^2) on the source bytes. Fine for small N.
210 PRINT "Pattern 1: FOR + JSONLEN + path concat"
220 N = JSONLEN(J$, "users")
230 FOR I = 0 TO N - 1
240 PATH$ = "users[" + STR$(I) + "].name"
250 PRINT "  "; JSON$(J$, PATH$)
260 NEXT
270 PRINT
280 REM --- Pattern 2: JSONUNPACK into a BASIC array + FOREACH
290 REM
300 REM JSONUNPACK redims a string array to match the JSON array length
310 REM and fills each slot with that element's JSON substring. Then
320 REM FOREACH iterates the BASIC array directly. Less repetitive than
330 REM path-concat, and FOREACH composes with any future multi-dim
340 REM extension.
350 PRINT "Pattern 2: JSONUNPACK + FOREACH"
360 DIM USERS$(0)
370 JSONUNPACK J$, "users" INTO USERS$
380 FOREACH USR$ IN USERS$
390 PRINT "  "; JSON$(USR$, "name"); " ("; JSONNUM(USR$, "age"); ")"
400 NEXT
410 PRINT
420 REM --- Pattern 3: DICT for object-key iteration
430 REM
440 REM JSON$ has no equivalent of "give me the Nth key of this object"
450 REM beyond JSONKEY$ on a string (which still re-scans on each call).
460 REM DICTLOAD parses once, then DICTLEN + DICTKEY$ walk the keys in
470 REM insertion order for free.
480 PRINT "Pattern 3: DICTLOAD + DICTLEN + DICTKEY$ over an object"
490 H = DICTLOAD(J$)
500 REM Walk the first user's keys.
510 NK = DICTLEN(H, "users[0]")
520 FOR I = 0 TO NK - 1
530 K$ = DICTKEY$(H, "users[0]", I)
540 PRINT "  users[0]."; K$; " = "; DICTGET$(H, "users[0]." + K$)
550 NEXT
560 DICTFREE H
570 PRINT
580 REM --- Notes
590 REM Pattern 2 has a DICT twin: DICTUNPACK h, path$ INTO arr$ does the
600 REM same fan-out from a map array, also composes with FOREACH.
610 REM
620 REM Rule of thumb:
630 REM   - One field, one read    -> JSON$ (no loop)
640 REM   - Walk an array          -> JSONUNPACK + FOREACH
650 REM   - Walk object keys       -> DICTLOAD + DICTKEY$
660 REM   - Mutate many fields     -> DICTLOAD, mutate, JSON$(h) at end
