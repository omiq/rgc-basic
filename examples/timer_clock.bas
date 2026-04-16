REM timer_clock.bas -- live London clock + background counter
REM
REM Fetches the current London time once via HTTP, then uses a TIMER
REM to update the clock display every second while the main loop runs
REM a visible counter -- showing cooperative "parallel" execution.
REM
REM Requires WASM build (HTTP$ only works in browser).

REM --- fetch initial time ---
PRINT "Fetching London time..."
u$ = "https://timeapi.io/api/TimeZone/zone?timeZone=Europe/London"
r$ = HTTP$(u$)
IF HTTPSTATUS() <> 200 THEN
  PRINT "HTTP error: " + STR(INT(HTTPSTATUS()))
  END
END IF

REM Parse "currentLocalTime":"2024-01-01T13:45:22" -> "13:45:22"
pos = INSTR(r$, "currentLocalTime") + 19
ft$ = MID$(r$, pos, 19)
hh = INT(VAL(MID$(ft$, 12, 2)))
mm = INT(VAL(MID$(ft$, 15, 2)))
ss = INT(VAL(MID$(ft$, 18, 2)))

REM Clear screen and draw layout
PRINT CHR$(147)
LOCATE 0, 0
PRINT "{white}London time:"
LOCATE 0, 2
PRINT "Main loop:"

REM --- timer handler: update clock display every second ---
FUNCTION TickClock()
  ss = ss + 1
  IF ss >= 60 THEN
    ss = 0
    mm = mm + 1
    IF mm >= 60 THEN
      mm = 0
      hh = hh + 1
      IF hh >= 24 THEN hh = 0
    END IF
  END IF
  h$ = RIGHT$("0" + STR(INT(hh)), 2)
  m$ = RIGHT$("0" + STR(INT(mm)), 2)
  s$ = RIGHT$("0" + STR(INT(ss)), 2)
  LOCATE 14, 0
  PRINT "{reverse on}" + h$ + ":" + m$ + ":" + s$ + "{reverse off}"
END FUNCTION

TIMER 1, 1000, TickClock

DO
REM --- main loop: count to 30, one step per second ---
n = 0
WHILE n < 30
  SLEEP 30
  n = n + 1
  LOCATE 11, 2
  PRINT STR(INT(n)) + "/30  "
WEND

TIMER CLEAR 1
LOCATE 0, 4
LOOP

