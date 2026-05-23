10 REM Conformance: string-literal backslash escapes (stable public API)
20 REM Each ASSERT halts with exit 2 on failure; run with --json-status.
30 ASSERT LEN("a\"b") = 3, "escaped quote keeps length 3"
40 ASSERT ASC(MID$("a\"b", 2, 1)) = 34, "middle char is a double-quote (34)"
50 ASSERT LEN("x\ny") = 3, "newline escape keeps length 3"
60 ASSERT ASC(MID$("x\ny", 2, 1)) = 10, "middle char is LF (10)"
70 ASSERT LEN("\t") = 1, "tab escape is one char"
80 ASSERT ASC("\t") = 9, "tab escape is code 9"
90 ASSERT LEN("\\") = 1, "double backslash is one literal backslash"
100 ASSERT ASC("\\") = 92, "backslash escape is code 92"
110 PRINT "string/escapes: all assertions passed"
120 END
