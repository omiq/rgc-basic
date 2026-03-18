REM Recursive factorial
FUNCTION fact(n)
  IF n <= 1 THEN RETURN 1
  RETURN n * fact(n - 1)
END FUNCTION
PRINT fact(5)
