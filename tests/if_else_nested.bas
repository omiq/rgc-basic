REM Nested IF/ELSE/END IF - various combinations
REM Exercises the structure that revealed the bug in delete-tag.bas:
REM   IF outer THEN ... ELSE ... IF inner THEN ... END IF ... END IF

PRINT "1. Simple nested IF/END IF inside ELSE (delete-tag pattern):"
X = 0
IF X = 1 THEN
    PRINT "WRONG"
ELSE
    Y = 1
    IF Y = 1 THEN
        PRINT "OK"
    END IF
END IF

PRINT "2. Nested IF/END IF no-else, inner false:"
A = 0
IF A = 0 THEN
    B = 1
    IF B = 0 THEN
        PRINT "WRONG"
    END IF
    PRINT "OK"
ELSE
    PRINT "WRONG"
END IF

PRINT "3. Triple nesting IF/ELSE/END IF:"
P = 1
Q = 1
R = 0
IF P = 1 THEN
    IF Q = 1 THEN
        IF R = 1 THEN
            PRINT "WRONG"
        ELSE
            PRINT "OK"
        END IF
    ELSE
        PRINT "WRONG"
    END IF
ELSE
    PRINT "WRONG"
END IF

PRINT "4. IF/END IF inside THEN branch:"
M = 0
IF M = 0 THEN
    N = 5
    IF N > 3 THEN
        PRINT "OK"
    END IF
ELSE
    PRINT "WRONG"
END IF

PRINT "5. delete-tag pattern: IF cond THEN ... ELSE ... IF x<>0 THEN ... END IF ... END IF:"
RC = 1
IF RC = 0 THEN
    PRINT "SKIP"
ELSE
    RC = 1
    IF RC <> 0 THEN
        PRINT "OK"
    END IF
END IF

PRINT "6. Multiple IF/END IF in same ELSE block:"
K = 1
IF K = 0 THEN
    PRINT "A"
ELSE
    IF 1 = 1 THEN
        PRINT "X"
    END IF
    IF 2 = 2 THEN
        PRINT "Y"
    END IF
    PRINT "Z"
END IF

PRINT "7. Nested IF with condition containing parentheses:"
Z = 1
IF Z = 1 THEN
    IF (1 + 1) = 2 THEN
        PRINT "OK"
    END IF
END IF

PRINT "DONE"
