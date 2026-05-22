10 REM json_write_basics: building a JSON string from scratch.
20 REM
30 REM Start with JSONNEW$ ("object" or "array") and chain JSONPUT$
40 REM calls. Each JSONPUT$ returns a new JSON string with the value
50 REM set at the given path. Auto-escaping means you never glue
60 REM quotes by hand.
70 REM
80 J$ = JSONNEW$("object")
90 REM Strings. The escape is automatic — embedded quotes / newlines
100 REM / backslashes get JSON-escaped in the output.
110 J$ = JSONPUT$(J$, "name", "Alice")
120 J$ = JSONPUT$(J$, "quote", "she said " + CHR$(34) + "hi" + CHR$(34))
130 REM Numbers. Integral doubles emit without a decimal; non-integral
140 REM use round-trip-safe %.17g formatting.
150 J$ = JSONPUT$(J$, "age", 30)
160 J$ = JSONPUT$(J$, "score", 3.5)
170 J$ = JSONPUT$(J$, "neg", -7)
180 REM Bool: BASIC has no first-class bool, so the API has dedicated
190 REM PUT verbs. Non-zero numeric → true; zero → false.
200 J$ = JSONPUTBOOL$(J$, "vip", 1)
210 J$ = JSONPUTBOOL$(J$, "blocked", 0)
220 REM Null: separate verb because BASIC has no null literal.
230 J$ = JSONPUTNULL$(J$, "deleted_at")
240 REM Nested object: dot notation. Intermediates are auto-vivified.
250 J$ = JSONPUT$(J$, "address.city", "Cardiff")
260 J$ = JSONPUT$(J$, "address.zip", "CF10")
270 REM Array: bracket notation. Sparse writes fill the gap with null.
280 J$ = JSONPUT$(J$, "tags[0]", "admin")
290 J$ = JSONPUT$(J$, "tags[2]", "beta")
300 PRINT "Result:"
310 PRINT J$
320 PRINT
330 REM Each JSONPUT$ re-parses the whole input string, so chains over
340 REM ~10 calls on a large payload start to add up. For real-world
350 REM construction beyond a handful of fields, build a MAP and serialise
360 REM once with JSON$(handle) — see examples/map_roundtrip.bas.
