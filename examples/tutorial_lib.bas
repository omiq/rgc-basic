REM === Tutorial library: reusable functions ===
REM Include this file with: #INCLUDE "tutorial_lib.bas"

REM Returns 1 if n is prime, 0 otherwise
FUNCTION is_prime(n)
  IF n < 2 THEN RETURN 0
  IF n = 2 THEN RETURN 1
  IF n - 2 * INT(n / 2) = 0 THEN RETURN 0
  d = 3
  WHILE d * d <= n
    IF n - d * INT(n / d) = 0 THEN RETURN 0
    d = d + 2
  WEND
  RETURN 1
END FUNCTION

REM Greatest common divisor of a and b (Euclid's algorithm)
FUNCTION gcd(a, b)
  WHILE b <> 0
    t = b
    b = a - b * INT(a / b)
    a = t
  WEND
  RETURN a
END FUNCTION

REM Factorial: n! for n >= 0
FUNCTION factorial(n)
  IF n <= 0 THEN RETURN 1
  result = 1
  i = 1
  WHILE i <= n
    result = result * i
    i = i + 1
  WEND
  RETURN result
END FUNCTION

REM Returns a greeting string based on hour (0-23)
FUNCTION greet(hour)
  IF hour < 12 THEN
    RETURN "Good morning"
  ELSE
    IF hour < 18 THEN
      RETURN "Good afternoon"
    ELSE
      RETURN "Good evening"
    END IF
  END IF
END FUNCTION
