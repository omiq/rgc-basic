REM buffer_basic_test -- allocate, write, read, measure, free a BUFFER.
REM Uses existing OPEN/PRINT#/INPUT#/CLOSE against BUFFERPATH$(slot).

BUFFERNEW 0

REM Write two tokens into the buffer via its path.
OPEN 1, 1, 1, BUFFERPATH$(0)
PRINT#1, "HELLO"
PRINT#1, "WORLD"
CLOSE 1

REM BUFFERLEN should be 12 bytes (HELLO\nWORLD\n).
L = BUFFERLEN(0)
IF L <> 12 THEN PRINT "FAIL: expected 12 bytes, got "; L: END

REM BUFFERPATH$ should be non-empty.
P$ = BUFFERPATH$(0)
IF LEN(P$) = 0 THEN PRINT "FAIL: empty buffer path": END

REM Read the two tokens back (INPUT# splits on commas and newlines).
OPEN 2, 1, 0, BUFFERPATH$(0)
INPUT#2, A$
INPUT#2, B$
CLOSE 2

IF A$ <> "HELLO" THEN PRINT "FAIL: line 1 = ["; A$; "]": END
IF B$ <> "WORLD" THEN PRINT "FAIL: line 2 = ["; B$; "]": END

BUFFERFREE 0

REM After free, BUFFERLEN returns 0 and BUFFERPATH$ returns "".
IF BUFFERLEN(0) <> 0 THEN PRINT "FAIL: BUFFERLEN after free": END
IF LEN(BUFFERPATH$(0)) <> 0 THEN PRINT "FAIL: BUFFERPATH$ after free": END

REM Idempotent: second BUFFERFREE is a no-op.
BUFFERFREE 0

PRINT "OK"
