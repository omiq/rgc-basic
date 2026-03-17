e$ = "curl -s -f 'https://timeapi.io/api/timezone/zone?TIMEZONE=EUROPE/LONDON'"
r$ = EXEC$(e$)
ft$ = MID$(r$, instr(r$, "currentLocalTime")+19, 19)
d$ = LEFT$(ft$, 10)
t$ = MID$(ft$, 12, 8)
print ""
print "The current date and time in London is: {white}{reverse on}" + d$ + "{reverse off} {reverse on}" + t$ + "{reverse off}"
print ""
