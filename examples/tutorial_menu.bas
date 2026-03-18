REM ============================================================
REM Tutorial: Menu with IF ELSE END IF and WHILE WEND
REM Run: ./basic examples/tutorial_menu.bas
REM ============================================================

#INCLUDE "tutorial_lib.bas"

PRINT "=== Math Helpers Menu ==="
PRINT " 1. Factorial"
PRINT " 2. GCD of two numbers"
PRINT " 3. Check if prime"
PRINT " 4. Quit"
PRINT

done = 0
WHILE done = 0
  INPUT "Choice (1-4)"; c

  IF c = 1 THEN
    INPUT "Number"; n
    PRINT "factorial("; n; ") ="; factorial(n)
  END IF
  IF c = 2 THEN
    INPUT "First number"; a
    INPUT "Second number"; b
    PRINT "gcd("; a; ","; b; ") ="; gcd(a, b)
  END IF
  IF c = 3 THEN
    INPUT "Number"; n
    p = is_prime(n)
    PRINT n; " -> "; p; " (1=prime, 0=not)"
  END IF
  IF c = 4 THEN
    PRINT "Goodbye!"
    done = 1
  END IF
  IF c < 1 OR c > 4 THEN
    PRINT "Invalid choice"
  END IF
  PRINT
WEND
END
