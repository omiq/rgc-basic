REM timer_demo.bas -- exercise the TIMER statement
REM
REM SLEEP takes 60Hz ticks (1 tick ~ 16ms).
REM Timer 1 fires every ~160ms (10 ticks), stops itself after 5 fires.
REM Timer 2 fires every ~500ms (30 ticks) for the duration.
REM Main loop runs for ~3 seconds (180 ticks = 30 loops x 6 ticks each).

tc = 0
tk = 0

FUNCTION OnTick()
  tc = tc + 1
  PRINT "tick #" + STR(INT(tc))
  IF tc >= 5 THEN
    TIMER STOP 1
    PRINT "timer 1 stopped"
  END IF
END FUNCTION

FUNCTION OnTock()
  tk = tk + 1
  PRINT "  tock #" + STR(INT(tk))
END FUNCTION

TIMER 1, 160, OnTick
TIMER 2, 500, OnTock

REM Short sleeps so timers can fire between iterations
loops = 0
WHILE loops < 30
  SLEEP 6
  loops = loops + 1
WEND

TIMER CLEAR 1
TIMER CLEAR 2
PRINT "done. ticks=" + STR(INT(tc)) + " tocks=" + STR(INT(tk))
