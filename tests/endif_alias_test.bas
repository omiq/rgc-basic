REM ENDIF (one word) alias for END IF. Regression for buttons.bas pattern:
REM an inline IF followed by a block IF that closes with ENDIF used to raise
REM "END IF expected" because the forward scanner only matched "END IF".

LET D = 0
IF 1 = 1 THEN LET D = 1
IF D = 1 THEN
  PRINT "INLINE+BLOCK OK"
ENDIF

REM False-branch skip across nested ENDIF must land correctly.
LET X = 0
IF X = 1 THEN
  PRINT "SHOULD NOT PRINT"
  IF X = 0 THEN
    PRINT "NOR THIS"
  ENDIF
ENDIF
PRINT "AFTER SKIP"

REM Mixed ENDIF / END IF with ELSE.
LET Y = 2
IF Y = 2 THEN
  IF Y > 0 THEN
    PRINT "INNER TRUE"
  ELSE
    PRINT "INNER FALSE"
  ENDIF
  PRINT "OUTER BODY"
END IF

PRINT "OK"
