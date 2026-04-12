REM London clock via HTTP$ (browser WASM). Target API must send CORS headers.
REM Native CLI: use EXEC$("curl -s ...") — HTTP$ returns "" outside WASM.
u$ = "https://timeapi.io/api/TimeZone/zone?timeZone=Europe/London"
r$ = HTTP$(u$)
IF HTTPSTATUS() <> 200 THEN PRINT "HTTP "; HTTPSTATUS(): END
ft$ = MID$(r$, instr(r$, "currentLocalTime")+19, 19)
d$ = LEFT$(ft$, 10)
t$ = MID$(ft$, 12, 8)
print "": print "The current date and time in London is: {white}{reverse on}";
print d$ + "{reverse off} {reverse on}" + t$ + "{reverse off}"
print ""
