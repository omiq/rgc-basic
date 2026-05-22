10 REM json_read_basics: extracting values from a JSON string.
20 REM
30 REM The 2-arg form of JSON$ pulls a field out by path. The path is
40 REM dot+bracket notation, same as JavaScript:
50 REM   "name"          top-level key
60 REM   "user.email"    nested key inside an object
70 REM   "tags[0]"       array element by index
80 REM   "items[2].sku"  mixed object+array
90 REM
100 REM CHR$(34) is the BASIC way to embed a quote character inside a
110 REM string literal — there is no \" escape. To keep the source
120 REM readable, build the JSON once with Q$ = CHR$(34) and concatenate.
130 Q$ = CHR$(34)
140 J$ = "{" + Q$ + "name" + Q$ + ":" + Q$ + "Alice" + Q$
150 J$ = J$ + "," + Q$ + "age" + Q$ + ":30"
160 J$ = J$ + "," + Q$ + "vip" + Q$ + ":true"
170 J$ = J$ + "," + Q$ + "tags" + Q$ + ":[" + Q$ + "admin" + Q$ + "," + Q$ + "beta" + Q$ + "]"
180 J$ = J$ + "}"
190 PRINT "Source: "; J$
200 PRINT
210 REM String fields — JSON$ returns the value as a string.
220 PRINT "name : "; JSON$(J$, "name")
230 REM Numeric fields — JSONNUM parses straight to a double. JSON$
240 REM would give you "30" the string; JSONNUM gives you 30 the number.
250 PRINT "age  : "; JSONNUM(J$, "age")
260 REM Booleans — JSONBOOL returns 1 for true, 0 for false or missing.
270 IF JSONBOOL(J$, "vip") = 1 THEN PRINT "vip  : yes" ELSE PRINT "vip  : no"
280 REM Type introspection — JSONTYPE$ returns "string", "number",
290 REM "object", "array", "null", "bool", or "" for missing keys.
300 PRINT "type of tags : "; JSONTYPE$(J$, "tags")
310 PRINT "type of zzz  : "; JSONTYPE$(J$, "zzz")
320 PRINT
330 REM Iterating an array. JSONLEN gives the count; JSONUNPACK fans
340 REM the elements out into a BASIC string array so FOREACH can walk
350 REM them — much tidier than gluing path indices by hand.
360 PRINT "Tags via JSONUNPACK + FOREACH:"
370 DIM TAGS$(0)
380 JSONUNPACK J$, "tags" INTO TAGS$
390 FOREACH T$ IN TAGS$
400 PRINT "  - "; T$
410 NEXT
420 PRINT
430 REM Missing keys return empty / 0 — no crash.
440 PRINT "JSON$  on missing : ["; JSON$(J$, "missing"); "]"
450 PRINT "JSONNUM on missing : "; JSONNUM(J$, "missing")
