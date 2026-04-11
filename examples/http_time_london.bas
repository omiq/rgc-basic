10 REM London clock via HTTP$ (browser WASM). Target API must send CORS headers.
20 REM Native CLI: use EXEC$("curl -s ...") — HTTP$ returns "" outside WASM.
30 U$ = "https://timeapi.io/api/TimeZone/zone?timeZone=Europe/London"
40 R$ = HTTP$(U$)
50 IF HTTPSTATUS() <> 200 THEN PRINT "HTTP error "; HTTPSTATUS(): END
60 P = INSTR(R$, "dateTime")
70 IF P < 1 THEN P = INSTR(R$, "currentLocalTime")
80 IF P < 1 THEN PRINT "parse: unexpected JSON": END
90 Q = INSTR(R$, CHR$(34), P)
100 IF Q < 1 THEN PRINT "parse: no quote": END
110 FT$ = MID$(R$, Q + 1, 19)
120 D$ = LEFT$(FT$, 10)
130 T$ = MID$(FT$, 12, 8)
140 PRINT ""
150 PRINT "London (Europe/London): "; D$; " "; T$
160 END
