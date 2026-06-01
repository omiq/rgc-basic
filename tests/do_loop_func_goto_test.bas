REM Regression: a GOTO inside a FUNCTION must not clobber the caller's
REM DO/LOOP frame. Before the fix this halted with "LOOP without DO" because
REM goto_unwind_structured_stacks() zeroed do_top globally instead of
REM unwinding only to the current UDF's floor. See to-do.md / CHANGELOG.

FAILS = 0

REM 1. DO loop whose body calls a function that does a forward GOTO each
REM    pass. The loop must keep iterating and terminate normally.
S = 1 : COUNT = 0
DO
  IF S >= 1 THEN S = StepIt(S)
  COUNT = COUNT + 1
LOOP UNTIL S = 0
IF COUNT <> 4 THEN PRINT "FAIL 1 expected 4 got "; COUNT : FAILS = FAILS + 1

REM 2. A function with its OWN inner DO + GOTO out of it returns correctly
REM    and leaves the caller's state intact.
R = SumTo(5)
IF R <> 15 THEN PRINT "FAIL 2 expected 15 got "; R : FAILS = FAILS + 1

REM 3. The outer DO is still usable after those calls.
S = 1 : COUNT = 0
DO
  IF S >= 1 THEN S = StepIt(S)
  COUNT = COUNT + 1
LOOP UNTIL S = 0
IF COUNT <> 4 THEN PRINT "FAIL 3 expected 4 got "; COUNT : FAILS = FAILS + 1

IF FAILS > 0 THEN PRINT "DO/LOOP+FUNC-GOTO: "; FAILS; " failure(s)" : STOP
PRINT "DO/LOOP+FUNC-GOTO: all 3 cases passed"
END

FUNCTION StepIt(N)
  IF N > 3 THEN GOTO Halt
  RETURN N + 1
Halt: RETURN 0
END FUNCTION

FUNCTION SumTo(M)
  T = 0 : I = 1
  DO
    T = T + I
    IF I >= M THEN GOTO Fin
    I = I + 1
  LOOP
Fin: RETURN T
END FUNCTION
