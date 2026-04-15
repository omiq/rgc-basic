REM buffer_slots_test -- concurrent BUFFER slots are independent.

BUFFERNEW 0
BUFFERNEW 5
BUFFERNEW 15

OPEN 1, 1, 1, BUFFERPATH$(0)
PRINT#1, "ZERO"
CLOSE 1

OPEN 1, 1, 1, BUFFERPATH$(5)
PRINT#1, "FIVE-LONGER-PAYLOAD"
CLOSE 1

OPEN 1, 1, 1, BUFFERPATH$(15)
PRINT#1, "FIFTEEN"
CLOSE 1

OPEN 1, 1, 0, BUFFERPATH$(0)
INPUT#1, A$
CLOSE 1
IF A$ <> "ZERO" THEN PRINT "FAIL: slot 0 = ["; A$; "]": END

OPEN 1, 1, 0, BUFFERPATH$(5)
INPUT#1, A$
CLOSE 1
IF A$ <> "FIVE-LONGER-PAYLOAD" THEN PRINT "FAIL: slot 5 = ["; A$; "]": END

OPEN 1, 1, 0, BUFFERPATH$(15)
INPUT#1, A$
CLOSE 1
IF A$ <> "FIFTEEN" THEN PRINT "FAIL: slot 15 = ["; A$; "]": END

REM Sizes should differ.
IF BUFFERLEN(5) <= BUFFERLEN(0) THEN PRINT "FAIL: slot 5 should be larger": END

REM Paths must be distinct.
IF BUFFERPATH$(0) = BUFFERPATH$(5) THEN PRINT "FAIL: paths collided": END

REM BUFFERNEW on an already-used slot replaces (idempotent) -- the file is
REM recreated empty and gets a new path.
P0OLD$ = BUFFERPATH$(0)
BUFFERNEW 0
IF BUFFERPATH$(0) = P0OLD$ THEN PRINT "FAIL: BUFFERNEW did not rotate path": END
IF BUFFERLEN(0) <> 0 THEN PRINT "FAIL: replacement not zero-size": END

BUFFERFREE 0
BUFFERFREE 5
BUFFERFREE 15

PRINT "OK"
