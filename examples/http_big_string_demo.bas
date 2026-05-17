REM http_big_string_demo -- fetch a JSON payload larger than the old
REM 4 KB MAX_STR_LEN cap directly into a regular string, then use the
REM normal string intrinsics (LEN, INSTR, MID$, JSON$) on it.
REM
REM Before big strings (shipped 2026-05-17) this would have silently
REM truncated at byte 4095. The workaround was buffer_http_demo.bas —
REM route through BUFFERFETCH + GET# byte-scan. With #OPTION MAXSTR
REM UNLIMITED (or -maxstr unlimited on the CLI) HTTP$ now returns the
REM full response and every string intrinsic works on it.
REM
REM HTTP$ is only available in the browser/canvas WASM build and in
REM basic-gfx with network compiled in. Plain terminal CLI returns ""
REM (see http_time_london.bas note).

#OPTION MAXSTR UNLIMITED

REM jsonplaceholder /comments is ~120 KB JSON, served with CORS.
U$ = "https://jsonplaceholder.typicode.com/comments"
R$ = HTTP$(U$)
IF HTTPSTATUS() <> 200 THEN PRINT "HTTP "; HTTPSTATUS(): END

PRINT "fetched "; LEN(R$); " bytes"
IF LEN(R$) < 4096 THEN
    PRINT "(unexpectedly small — the demo wants a >4 KB response)"
END IF

REM Use plain INSTR on the whole payload. Pre-big-strings, INSTR
REM beyond byte 4095 returned 0 because R$ was truncated.
P = INSTR(R$, "@")
IF P > 0 THEN
    PRINT "first @ at byte "; P
    PRINT "context: "; MID$(R$, P - 5, 20)
END IF

REM JSON$ on the full payload — pick the email of comment #50.
E$ = JSON$(R$, "[49].email")
PRINT "comment 50 email: "; E$

REM Count how many "postId" keys appear — proves we scanned past 4 KB.
N = 0
POS = 1
DO
    P = INSTR(MID$(R$, POS), "postId")
    IF P = 0 THEN EXIT
    N = N + 1
    POS = POS + P + 5
LOOP
PRINT "postId occurrences: "; N
