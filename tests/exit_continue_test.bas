REM ** EXIT / CONTINUE regression test **

PRINT "=== EXIT FOR ==="
FOR I = 1 TO 10
  IF I = 4 THEN EXIT FOR
  PRINT I;
NEXT I
PRINT "| done"

PRINT "=== CONTINUE FOR (skip evens) ==="
FOR I = 1 TO 8
  IF I = I \ 2 * 2 THEN CONTINUE FOR
  PRINT I;
NEXT I
PRINT "| done"

PRINT "=== EXIT DO / bare EXIT ==="
X = 0
DO
  X = X + 1
  IF X = 3 THEN EXIT
  PRINT X;
LOOP
PRINT "| X=";X

PRINT "=== CONTINUE DO ==="
N = 0 : C = 0
DO
  N = N + 1
  IF N > 6 THEN EXIT DO
  IF N = N \ 2 * 2 THEN CONTINUE DO
  C = C + 1 : PRINT N;
LOOP
PRINT "| odds=";C

PRINT "=== EXIT WHILE ==="
W = 0
WHILE W < 100
  W = W + 1
  IF W = 5 THEN EXIT WHILE
WEND
PRINT "W=";W

PRINT "=== CONTINUE WHILE (skip multiples of 3) ==="
V = 0
WHILE V < 10
  V = V + 1
  IF V = V \ 3 * 3 THEN CONTINUE WHILE
  PRINT V;
WEND
PRINT "| done"

PRINT "=== nested FOR: EXIT FOR leaves inner only ==="
FOR A = 1 TO 3
  FOR B = 1 TO 3
    IF B = 2 THEN EXIT FOR
    PRINT A;B;"  ";
  NEXT B
NEXT A
PRINT "| done"

PRINT "=== block IF inside loop + CONTINUE FOR (no leak) ==="
FOR I = 1 TO 5
  IF I = 3 THEN
    PRINT "[three]";
    CONTINUE FOR
  END IF
  PRINT I;
NEXT I
PRINT "| done"

PRINT "=== EXIT FOR out of a SELECT CASE inside loop ==="
FOR I = 1 TO 9
  SELECT CASE I
    CASE 4
      EXIT FOR
    CASE ELSE
      PRINT I;
  END SELECT
NEXT I
PRINT "| done"

PRINT "=== FOREACH + EXIT FOR ==="
DIM A(4)
A(0)=10 : A(1)=20 : A(2)=30 : A(3)=40 : A(4)=50
FOREACH V IN A
  IF V = 30 THEN EXIT FOR
  PRINT V;
NEXT V
PRINT "| done"

PRINT "=== EXIT/CONTINUE inside FUNCTION ==="
PRINT FirstOddOver(10)
PRINT SumSkip3(6)
PRINT "all done"
END

FUNCTION FirstOddOver(LO)
  FOR K = LO+1 TO LO+20
    IF K = K \ 2 * 2 THEN CONTINUE FOR
    RETURN K
  NEXT K
  RETURN -1
END FUNCTION

FUNCTION SumSkip3(M)
  T = 0
  FOR K = 1 TO M
    IF K = 3 THEN CONTINUE FOR
    T = T + K
  NEXT K
  RETURN T
END FUNCTION
