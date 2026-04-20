REM backslash escape sequences inside double-quoted strings.
REM Expanded at load time. Raw bytes after expansion:
REM   \n -> CHR$(10) LF     \r -> CHR$(13) CR
REM   \t -> CHR$(9)  TAB    \0 -> CHR$(0)  NUL
REM   \" -> CHR$(34) quote  \\ -> CHR$(92) backslash
REM   \x (unknown) -> left as two chars ('\' then 'x')

S$ = "A\nB"
IF LEN(S$) <> 3 THEN PRINT "FAIL len A\\nB="; LEN(S$) : END
IF ASC(MID$(S$, 1, 1)) <> 65 THEN PRINT "FAIL [0]" : END
IF ASC(MID$(S$, 2, 1)) <> 10 THEN PRINT "FAIL [1] expected LF got"; ASC(MID$(S$, 2, 1)) : END
IF ASC(MID$(S$, 3, 1)) <> 66 THEN PRINT "FAIL [2]" : END

IF ASC(MID$("X\rY", 2, 1)) <> 13 THEN PRINT "FAIL \\r CR" : END
IF ASC(MID$("X\tY", 2, 1)) <> 9  THEN PRINT "FAIL \\t TAB" : END
IF ASC(MID$("X\\Y", 2, 1)) <> 92 THEN PRINT "FAIL \\\\ backslash" : END
IF ASC(MID$("X\"Y", 2, 1)) <> 34 THEN PRINT "FAIL \\\" quote" : END
REM \0 expands to CHR$(0) at load time, but the interpreter's string
REM concat uses C-style strcpy/strlen which drops embedded NULs — the
REM resulting "X"+CHR$(0)+"Y" collapses to "XY". Raw NULs in strings
REM need a wider string-rep overhaul (tracked in to-do).

REM Unknown escape: backslash stays literal.
IF ASC(MID$("X\zY", 2, 1)) <> 92 THEN PRINT "FAIL unknown \\z not backslash" : END
IF ASC(MID$("X\zY", 3, 1)) <> 122 THEN PRINT "FAIL unknown \\z z-char" : END

REM Escape before a {TOKEN} — escape runs first, token still expands.
S$ = "\nREM"
IF LEN(S$) <> 4 THEN PRINT "FAIL escape + text"; LEN(S$) : END
IF ASC(MID$(S$, 1, 1)) <> 10 THEN PRINT "FAIL escape before text" : END

PRINT "OK"
END
