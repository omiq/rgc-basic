REM UDF returning no value (like GOSUB)
FUNCTION sayhi()
  PRINT "HELLO"
  RETURN
END FUNCTION
sayhi()
PRINT "DONE"
