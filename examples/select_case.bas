REM ** SELECT CASE demo -- modern multi-way dispatch in rgc-basic **
REM ** Replaces ON x GOTO chains and long IF/ELSEIF ladders. **
REM ** Run: ./basic examples/select_case.bas **

PRINT "=== Grade by score (numeric, ranges + IS) ==="
FOR S = 35 TO 95 STEP 15
  SELECT CASE S
    CASE IS >= 90
      PRINT S; " -> A"
    CASE 80 TO 89
      PRINT S; " -> B"
    CASE 70 TO 79
      PRINT S; " -> C"
    CASE 60 TO 69
      PRINT S; " -> D"
    CASE ELSE
      PRINT S; " -> FAIL"
  END SELECT
NEXT S

PRINT
PRINT "=== Command parser (string, comma lists) ==="
DIM CMD$(4)
CMD$(0) = "N"
CMD$(1) = "FIRE"
CMD$(2) = "QUIT"
CMD$(3) = "LOOK"
CMD$(4) = "XYZZY"
FOR I = 0 TO 4
  PRINT CMD$(I); " -> ";
  SELECT CASE CMD$(I)
    CASE "N", "S", "E", "W"
      PRINT "move"
    CASE "FIRE", "SHOOT"
      PRINT "attack"
    CASE "LOOK"
      PRINT "examine surroundings"
    CASE "QUIT"
      PRINT "leave the game"
    CASE ELSE
      PRINT "huh?"
  END SELECT
NEXT I
END
