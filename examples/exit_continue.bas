REM ** EXIT / CONTINUE demo -- structured loop control in rgc-basic **
REM ** No GOTO-to-a-label-on-NEXT needed. **
REM ** Run: ./basic examples/exit_continue.bas **

PRINT "=== Find the first prime above 50 (EXIT FOR) ==="
FOR N = 51 TO 200
  ISPRIME = 1
  FOR D = 2 TO N - 1
    IF N = N \ D * D THEN ISPRIME = 0 : EXIT FOR
  NEXT D
  IF ISPRIME = 1 THEN PRINT "first prime > 50 is"; N : EXIT FOR
NEXT N

PRINT
PRINT "=== Sum 1..20 but skip multiples of 3 (CONTINUE FOR) ==="
TOTAL = 0
FOR I = 1 TO 20
  IF I = I \ 3 * 3 THEN CONTINUE FOR
  TOTAL = TOTAL + I
NEXT I
PRINT "total ="; TOTAL

PRINT
PRINT "=== Countdown with early break (EXIT DO) ==="
X = 10
DO
  PRINT X;
  X = X - 1
  IF X = 4 THEN EXIT DO
LOOP
PRINT "| launch aborted at"; X

PRINT
PRINT "=== Print odd numbers 1..12 (CONTINUE WHILE) ==="
W = 0
WHILE W < 12
  W = W + 1
  IF W = W \ 2 * 2 THEN CONTINUE WHILE
  PRINT W;
WEND
PRINT
END
