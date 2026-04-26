REM Regression: parser previously failed with "Missing THEN" when an
REM inline IF called a UDF whose body ran a WHILE loop containing
REM another UDF call. Same root cause as function_nested_call_value
REM (udf_returned flag leak); the value contamination corrupted
REM statement_pos restoration so the parser landed mid-expression
REM at the next iteration.
FUNCTION inner()
  RETURN 13
END FUNCTION

FUNCTION outer()
  i = 0
  WHILE i < 1
    x = inner()
    i = i + 1
  WEND
  RETURN 0
END FUNCTION

IF outer() = 1 THEN PRINT "branch unexpectedly taken"
PRINT "ok"
