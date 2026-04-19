' GET demo — press a key to see its ASCII code. ESC quits.

TEXTAT 10, 20, "PRESS A KEY (ESC TO QUIT):"

DO
  GET K$
  IF K$ <> "" THEN
    IF ASC(K$) = 27 THEN EXIT
    PRINT "{HOME}ASC(K$) = "; ASC(K$); "       "
  END IF
  SLEEP 1
LOOP
