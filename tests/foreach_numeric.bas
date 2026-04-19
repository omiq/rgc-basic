DIM A(3)
A(0) = 1 : A(1) = 2 : A(2) = 4 : A(3) = 8
T = 0
FOREACH V IN A()
  T = T + V
NEXT V
IF T <> 15 THEN PRINT "FAIL sum="; T : END
PRINT "OK"
END
