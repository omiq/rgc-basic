REM Regression: GOTO out of a nested IF/FOR block must unwind the
REM structured stacks so repeated jumps don't overflow MAX_IF_DEPTH /
REM MAX_FOR / MAX_WHILE_DEPTH.
REM
REM Pre-fix: each iteration's GOTO leaked if_depth + for_top by 1.
REM After ~16 iterations the parser halted with "IF nesting too deep".
REM Post-fix: goto_unwind_structured_stacks() resets the per-UDF
REM counters back to the floor at GOTO time.

FOR I = 0 TO 99
  FOR J = 0 TO 9
    IF J = 5 THEN
      IF I = 0 THEN
        GOTO OuterDone
      END IF
      GOTO InnerDone
    END IF
  NEXT J
  InnerDone:
NEXT I
OuterDone:
PRINT "ok"
