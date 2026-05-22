1 REM Phase 2 JSON write helpers: JSONNEW$, JSONPUT$, JSONPUTNULL$, JSONPUTBOOL$, JSONSTATUS
2 Q$ = CHR$(34)
3 PRINT "Testing JSONNEW$..."
10 IF JSONNEW$("object") = "{}" THEN PRINT "OK: new object"
11 IF JSONNEW$("array") = "[]" THEN PRINT "OK: new array"
12 R$ = JSONNEW$("bogus")
13 IF R$ = "" AND JSONSTATUS() = 2 THEN PRINT "OK: bogus kind sets status 2"
20 PRINT "Testing JSONPUT$ replace on existing key..."
30 J$ = JSONPUT$("{" + Q$ + "n" + Q$ + ":1}", "n", 42)
31 IF J$ = "{" + Q$ + "n" + Q$ + ":42}" THEN PRINT "OK: replace number"
32 J$ = JSONPUT$("{" + Q$ + "s" + Q$ + ":" + Q$ + "old" + Q$ + "}", "s", "new")
33 IF J$ = "{" + Q$ + "s" + Q$ + ":" + Q$ + "new" + Q$ + "}" THEN PRINT "OK: replace string"
40 PRINT "Testing JSONPUT$ auto-vivify object chain..."
50 J$ = JSONPUT$("{}", "a", 1)
51 IF J$ = "{" + Q$ + "a" + Q$ + ":1}" THEN PRINT "OK: simple add to empty"
52 J$ = JSONPUT$("{}", "a.b.c", 7)
53 IF J$ = "{" + Q$ + "a" + Q$ + ":{" + Q$ + "b" + Q$ + ":{" + Q$ + "c" + Q$ + ":7}}}" THEN PRINT "OK: deep auto-vivify"
54 J$ = JSONPUT$("{" + Q$ + "x" + Q$ + ":1}", "y", 2)
55 IF J$ = "{" + Q$ + "x" + Q$ + ":1," + Q$ + "y" + Q$ + ":2}" THEN PRINT "OK: add second key with comma"
60 PRINT "Testing JSONPUT$ array..."
70 J$ = JSONPUT$("{" + Q$ + "items" + Q$ + ":[]}", "items[0]", "first")
71 IF J$ = "{" + Q$ + "items" + Q$ + ":[" + Q$ + "first" + Q$ + "]}" THEN PRINT "OK: fill empty array"
72 J$ = JSONPUT$("{" + Q$ + "items" + Q$ + ":[" + Q$ + "a" + Q$ + "]}", "items[3]", "d")
73 IF J$ = "{" + Q$ + "items" + Q$ + ":[" + Q$ + "a" + Q$ + ",null,null," + Q$ + "d" + Q$ + "]}" THEN PRINT "OK: sparse fill with null"
74 J$ = JSONPUT$("{}", "items[2]", 9)
75 IF J$ = "{" + Q$ + "items" + Q$ + ":[null,null,9]}" THEN PRINT "OK: auto-vivify array with sparse"
80 PRINT "Testing JSONPUT$ value types..."
90 J$ = JSONPUT$("{}", "n", 12345678)
91 IF J$ = "{" + Q$ + "n" + Q$ + ":12345678}" THEN PRINT "OK: large int exact"
92 J$ = JSONPUT$("{}", "f", 3.5)
93 IF J$ = "{" + Q$ + "f" + Q$ + ":3.5}" THEN PRINT "OK: simple decimal"
94 J$ = JSONPUT$("{}", "neg", -7)
95 IF J$ = "{" + Q$ + "neg" + Q$ + ":-7}" THEN PRINT "OK: negative int"
96 J$ = JSONPUT$("{}", "msg", "he " + Q$ + "said" + Q$)
97 IF J$ = "{" + Q$ + "msg" + Q$ + ":" + Q$ + "he \\" + Q$ + "said\\" + Q$ + Q$ + "}" THEN PRINT "OK: string value gets escaped"
100 PRINT "Testing JSONPUTNULL$..."
110 J$ = JSONPUTNULL$("{}", "x")
111 IF J$ = "{" + Q$ + "x" + Q$ + ":null}" THEN PRINT "OK: put null"
112 J$ = JSONPUTNULL$("{" + Q$ + "a" + Q$ + ":1}", "a")
113 IF J$ = "{" + Q$ + "a" + Q$ + ":null}" THEN PRINT "OK: replace with null"
120 PRINT "Testing JSONPUTBOOL$..."
130 J$ = JSONPUTBOOL$("{}", "ok", 1)
131 IF J$ = "{" + Q$ + "ok" + Q$ + ":true}" THEN PRINT "OK: true"
132 J$ = JSONPUTBOOL$("{}", "ok", 0)
133 IF J$ = "{" + Q$ + "ok" + Q$ + ":false}" THEN PRINT "OK: false"
134 J$ = JSONPUTBOOL$("{}", "ok", -1)
135 IF J$ = "{" + Q$ + "ok" + Q$ + ":true}" THEN PRINT "OK: nonzero -> true"
140 PRINT "Testing JSONSTATUS round-trip..."
150 J$ = JSONPUT$("{}", "a", 1)
151 IF JSONSTATUS() = 0 THEN PRINT "OK: status reset on success"
160 PRINT "Testing JSON$ round-trip with JSONPUT$..."
170 J$ = JSONPUT$(JSONPUT$(JSONPUT$(JSONNEW$("object"), "name", "Alice"), "age", 30), "tags[0]", "admin")
171 IF JSON$(J$, "name") = "Alice" THEN PRINT "OK: chained PUT readable name"
172 IF VAL(JSON$(J$, "age")) = 30 THEN PRINT "OK: chained PUT readable age"
173 IF JSON$(J$, "tags[0]") = "admin" THEN PRINT "OK: chained PUT readable array elem"
180 PRINT "Testing realistic build..."
190 H$ = JSONNEW$("object")
191 H$ = JSONPUT$(H$, "Authorization", "Bearer sk-test")
192 H$ = JSONPUT$(H$, "Content-Type", "application/json")
193 IF INSTR(H$, "Bearer sk-test") > 0 THEN PRINT "OK: built realistic headers"
194 B$ = JSONNEW$("object")
195 B$ = JSONPUT$(B$, "model", "claude-opus-4-7")
196 B$ = JSONPUT$(B$, "max_tokens", 1024)
197 B$ = JSONPUT$(B$, "messages[0].role", "user")
198 B$ = JSONPUT$(B$, "messages[0].content", "Hi")
199 IF JSON$(B$, "messages[0].role") = "user" THEN PRINT "OK: realistic nested array+object"
200 IF JSON$(B$, "messages[0].content") = "Hi" THEN PRINT "OK: realistic content path"
299 PRINT "Phase 2 test done."
