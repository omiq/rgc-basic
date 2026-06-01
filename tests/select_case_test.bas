REM ** SELECT CASE regression test **
REM ** Covers numeric, string, comma lists, IS relops, TO ranges, **
REM ** CASE ELSE, nesting, no-match, and SELECT inside FUNCTION. **

REM --- numeric exact + comma list ---
FOR I = 1 TO 5
  SELECT CASE I
    CASE 1
      PRINT "one"
    CASE 2, 3
      PRINT "two-or-three"
    CASE 4
      PRINT "four"
    CASE ELSE
      PRINT "other"
  END SELECT
NEXT I

REM --- IS relops and TO range ---
FOR N = -2 TO 12 STEP 2
  SELECT CASE N
    CASE IS < 0
      PRINT N; " neg"
    CASE 0
      PRINT N; " zero"
    CASE 1 TO 5
      PRINT N; " small"
    CASE IS >= 10
      PRINT N; " big"
    CASE ELSE
      PRINT N; " mid"
  END SELECT
NEXT N

REM --- string selector ---
DIM W$(3)
W$(0) = "cat"
W$(1) = "dog"
W$(2) = "fish"
W$(3) = "zzz"
FOR K = 0 TO 3
  SELECT CASE W$(K)
    CASE "cat", "dog"
      PRINT W$(K); " is a mammal"
    CASE "fish"
      PRINT W$(K); " swims"
    CASE ELSE
      PRINT W$(K); " unknown"
  END SELECT
NEXT K

REM --- nesting ---
FOR A = 1 TO 2
  FOR B = 1 TO 2
    SELECT CASE A
      CASE 1
        SELECT CASE B
          CASE 1
            PRINT "A1 B1"
          CASE ELSE
            PRINT "A1 Belse"
        END SELECT
      CASE ELSE
        PRINT "Aelse B"; B
    END SELECT
  NEXT B
NEXT A

REM --- SELECT inside FUNCTION with GOTO loop (stack discipline) ---
PRINT Classify(0)
PRINT Classify(7)
PRINT Classify(99)
PRINT "done"
END

FUNCTION Classify(X)
  C = 0
  Retry:
  C = C + 1
  SELECT CASE X
    CASE 0
      RETURN "z"
    CASE 1 TO 10
      IF C < 2 THEN GOTO Retry
      RETURN "loop-then-small"
    CASE ELSE
      RETURN "large"
  END SELECT
  RETURN "fell-through"
END FUNCTION
