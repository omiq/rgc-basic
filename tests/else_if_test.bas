REM ELSE IF / ELSEIF block-form chain — verify each branch fires for the
REM right condition and at most one branch's body runs.
REM
REM Block-only constraint: ELSE IF / ELSEIF only valid as a top-of-line
REM statement inside a block IF...END IF; no inline form.

FAILS = 0

REM 1. First branch true — middle / last / else skipped.
X = 0
IF 1 = 1 THEN
  X = 10
ELSE IF 1 = 1 THEN
  X = 20
ELSE
  X = 30
END IF
IF X <> 10 THEN PRINT "FAIL 1 expected 10 got "; X : FAILS = FAILS + 1

REM 2. Middle branch true.
Y = 0
IF 1 = 2 THEN
  Y = 10
ELSE IF 1 = 1 THEN
  Y = 20
ELSE
  Y = 30
END IF
IF Y <> 20 THEN PRINT "FAIL 2 expected 20 got "; Y : FAILS = FAILS + 1

REM 3. Else branch (all conds false).
Z = 0
IF 1 = 2 THEN
  Z = 10
ELSE IF 1 = 3 THEN
  Z = 20
ELSE
  Z = 30
END IF
IF Z <> 30 THEN PRINT "FAIL 3 expected 30 got "; Z : FAILS = FAILS + 1

REM 4. No trailing ELSE, all false → fall through, leave initial value.
W = 99
IF 1 = 2 THEN
  W = 1
ELSE IF 1 = 3 THEN
  W = 2
ELSE IF 1 = 4 THEN
  W = 3
END IF
IF W <> 99 THEN PRINT "FAIL 4 expected 99 got "; W : FAILS = FAILS + 1

REM 5. ELSEIF (one word) variant — same semantics.
A = 0
IF 1 = 2 THEN
  A = 10
ELSEIF 1 = 1 THEN
  A = 20
ELSE
  A = 30
END IF
IF A <> 20 THEN PRINT "FAIL 5 expected 20 got "; A : FAILS = FAILS + 1

REM 6. Mix two-word and one-word forms in same chain.
B = 0
IF 1 = 2 THEN
  B = 10
ELSE IF 1 = 3 THEN
  B = 20
ELSEIF 1 = 1 THEN
  B = 30
ELSE
  B = 40
END IF
IF B <> 30 THEN PRINT "FAIL 6 expected 30 got "; B : FAILS = FAILS + 1

REM 7. Last branch true.
C = 0
IF 1 = 2 THEN
  C = 10
ELSE IF 1 = 3 THEN
  C = 20
ELSE IF 1 = 1 THEN
  C = 30
END IF
IF C <> 30 THEN PRINT "FAIL 7 expected 30 got "; C : FAILS = FAILS + 1

REM 8. Long chain (5 branches), 4th true.
D = 0
IF 1 = 2 THEN
  D = 1
ELSE IF 1 = 3 THEN
  D = 2
ELSE IF 1 = 4 THEN
  D = 3
ELSE IF 1 = 1 THEN
  D = 4
ELSE
  D = 5
END IF
IF D <> 4 THEN PRINT "FAIL 8 expected 4 got "; D : FAILS = FAILS + 1

REM 9. Nested IF inside an ELSE IF body — inner block must not leak.
E = 0
INNER = 1
IF 1 = 2 THEN
  E = 10
ELSE IF 1 = 1 THEN
  IF INNER = 1 THEN
    E = 50
  ELSE
    E = 60
  END IF
ELSE
  E = 70
END IF
IF E <> 50 THEN PRINT "FAIL 9 expected 50 got "; E : FAILS = FAILS + 1

REM 10. Nested ELSE IF inside an ELSE IF body — both chains independent.
F = 0
IF 1 = 2 THEN
  F = 1
ELSE IF 1 = 1 THEN
  IF 1 = 2 THEN
    F = 10
  ELSE IF 1 = 1 THEN
    F = 20
  ELSE
    F = 30
  END IF
ELSE
  F = 40
END IF
IF F <> 20 THEN PRINT "FAIL 10 expected 20 got "; F : FAILS = FAILS + 1

REM 11. Outer-skip across nested ELSE IF chain — outer ELSE IF must find its
REM     own END IF, not the inner one.
G = 0
IF 1 = 2 THEN
  IF 1 = 1 THEN
    G = 10
  ELSE IF 1 = 1 THEN
    G = 20
  END IF
ELSE IF 1 = 1 THEN
  G = 30
END IF
IF G <> 30 THEN PRINT "FAIL 11 expected 30 got "; G : FAILS = FAILS + 1

REM 12. Condition expression with AND / OR — composite cond should re-evaluate
REM     correctly inside the chain.
H = 0
P = 1 : Q = 0
IF P = 0 THEN
  H = 1
ELSE IF P = 1 AND Q = 1 THEN
  H = 2
ELSE IF P = 1 AND Q = 0 THEN
  H = 3
ELSE
  H = 4
END IF
IF H <> 3 THEN PRINT "FAIL 12 expected 3 got "; H : FAILS = FAILS + 1

REM 13. ELSE IF condition that uses arithmetic + INT(): re-eval inside skip
REM     scanner must handle full expressions, not just bare comparisons.
J = 0
N13 = 7
IF (N13 * 2) = 0 THEN
  J = 1
ELSE IF INT(N13 / 3) = 2 THEN
  J = 2
ELSE
  J = 3
END IF
IF J <> 2 THEN PRINT "FAIL 13 expected 2 got "; J : FAILS = FAILS + 1

REM 14. Loop body with ELSE IF chain — runs many times, each iter picks one branch.
COUNT_NEG = 0 : COUNT_ZERO = 0 : COUNT_POS = 0
FOR I = -2 TO 2
  IF I < 0 THEN
    COUNT_NEG = COUNT_NEG + 1
  ELSE IF I = 0 THEN
    COUNT_ZERO = COUNT_ZERO + 1
  ELSE
    COUNT_POS = COUNT_POS + 1
  END IF
NEXT I
IF COUNT_NEG <> 2 THEN PRINT "FAIL 14a NEG "; COUNT_NEG : FAILS = FAILS + 1
IF COUNT_ZERO <> 1 THEN PRINT "FAIL 14b ZERO "; COUNT_ZERO : FAILS = FAILS + 1
IF COUNT_POS <> 2 THEN PRINT "FAIL 14c POS "; COUNT_POS : FAILS = FAILS + 1

REM 15. ELSE IF following a true THEN — entire ELSE IF body must NOT run.
K = 0
SIDE = 0
IF 1 = 1 THEN
  K = 100
ELSE IF 1 = 1 THEN
  K = 200
  SIDE = 1
END IF
IF K <> 100 THEN PRINT "FAIL 15a expected 100 got "; K : FAILS = FAILS + 1
IF SIDE <> 0 THEN PRINT "FAIL 15b ELSE IF body ran (SIDE = "; SIDE; ")" : FAILS = FAILS + 1

REM 16. ELSE IF chain inside a FUNCTION — local scope, RETURN works correctly.
FUNCTION Sign(N)
  IF N < 0 THEN
    RETURN -1
  ELSE IF N = 0 THEN
    RETURN 0
  ELSE
    RETURN 1
  END IF
END FUNCTION

IF Sign(-7) <> -1 THEN PRINT "FAIL 16a expected -1 got "; Sign(-7) : FAILS = FAILS + 1
IF Sign(0) <> 0 THEN PRINT "FAIL 16b expected 0 got "; Sign(0) : FAILS = FAILS + 1
IF Sign(7) <> 1 THEN PRINT "FAIL 16c expected 1 got "; Sign(7) : FAILS = FAILS + 1

REM 17. Variable named ELSEIFISH (alphanum-suffixed) must NOT match ELSEIF.
ELSEIFISH = 42
M = 0
IF 1 = 1 THEN
  M = ELSEIFISH
END IF
IF M <> 42 THEN PRINT "FAIL 17 expected 42 got "; M : FAILS = FAILS + 1

REM 18. String literal containing ELSE IF must not be parsed.
S$ = ""
IF 1 = 1 THEN
  S$ = "this ELSE IF stays literal"
END IF
IF S$ <> "this ELSE IF stays literal" THEN PRINT "FAIL 18 got "; S$ : FAILS = FAILS + 1

REM --- summary --------------------------------------------------------
IF FAILS > 0 THEN PRINT "ELSE-IF: "; FAILS; " failure(s)" : STOP
PRINT "ELSE-IF: all 18 cases passed"
END
