tc = 0

FUNCTION OnTick()
  tc = tc + 1
  IF tc >= 5 THEN
    TIMER STOP 1
  END IF
END FUNCTION

TIMER 1, 160, OnTick

loops = 0
WHILE loops < 30
  SLEEP 6
  loops = loops + 1
WEND

TIMER CLEAR 1
PRINT "ticks=" + STR(INT(tc))
