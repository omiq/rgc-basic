DIM N$(2)
N$(0) = "red" : N$(1) = "green" : N$(2) = "blue"
R$ = ""
FOREACH C$ IN N$
  R$ = R$ + C$ + "/"
NEXT C$
IF R$ <> "red/green/blue/" THEN PRINT "FAIL "; R$ : END
PRINT "OK"
END
