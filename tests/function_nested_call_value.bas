REM Regression: outer UDF must return its own value, not inner's.
REM Pre-fix: udf_returned global flag set by inner()'s RETURN was
REM seen by outer's run_until_udf_return loop, breaking the outer
REM loop early so outer never reached its own RETURN. Caller saw
REM inner's value instead. Fixed by clearing udf_returned in
REM invoke_udf after the nested call returns.
FUNCTION inner()
  RETURN 13
END FUNCTION

FUNCTION outer()
  t = inner()
  RETURN 7
END FUNCTION

V = outer()
IF V <> 7 THEN PRINT "FAIL got "; V
PRINT "outer="; V
