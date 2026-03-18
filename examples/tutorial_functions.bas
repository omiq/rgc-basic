#INCLUDE "tutorial_lib.bas"

REM ============================================================
REM Tutorial: FUNCTIONS, #INCLUDE, WHILE WEND, IF ELSE END IF
REM Run: ./basic examples/tutorial_functions.bas
REM Shows: library include, multi-line functions, WHILE loops,
REM         IF ELSE END IF blocks, recursion-friendly calls
REM ============================================================

PRINT "=== CBM-BASIC Modern Features Tutorial ==="
PRINT

REM --- Demo 1: Functions from included library ---
PRINT "1. Functions from tutorial_lib.bas"
PRINT "   factorial(5) ="; factorial(5)
PRINT "   gcd(48, 18) ="; gcd(48, 18)
PRINT "   is_prime(17) ="; is_prime(17); " (1=yes)"
PRINT "   is_prime(20) ="; is_prime(20); " (0=no)"
PRINT

REM --- Demo 2: greet() with IF ELSE END IF inside ---
PRINT "2. greet() uses IF ELSE END IF internally"
PRINT "   greet(9)  = "; greet(9)
PRINT "   greet(14) = "; greet(14)
PRINT "   greet(20) = "; greet(20)
PRINT

REM --- Demo 3: Local function with WHILE WEND ---
FUNCTION sumto(n)
  t = 0
  k = 1
  WHILE k <= n
    t = t + k
    k = k + 1
  WEND
  RETURN t
END FUNCTION

PRINT "3. Local function sumto(n) using WHILE WEND"
PRINT "   sumto(10) = 1+2+...+10 ="; sumto(10)
PRINT

REM --- Demo 4: Find first N primes with WHILE ---
PRINT "4. First 4 primes (using WHILE and is_prime):"
cnt = 0
nn = 2
WHILE cnt < 4
  pp = is_prime(nn)
  IF pp <> 0 THEN
    PRINT nn;
    cnt = cnt + 1
  END IF
  nn = nn + 1
WEND
PRINT
PRINT

REM --- Demo 5: Menu with IF ELSE END IF ---
PRINT "5. Demonstrating IF ELSE END IF:"
x = 7
IF x < 5 THEN
  PRINT "   x is less than 5"
ELSE
  IF x < 10 THEN
    PRINT "   x is between 5 and 9"
  ELSE
    PRINT "   x is 10 or more"
  END IF
END IF
PRINT

PRINT "=== Tutorial complete ==="
END
