tc = 0

FUNCTION OnTick()
  tc = tc + 1
  PRINT "tick"
END FUNCTION

FUNCTION Add(a, b)
  RETURN a + b
END FUNCTION

OnTick()
PRINT "sum = " + STR(Add(3, 4))
