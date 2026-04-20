REM integer divide — truncate toward zero, pairs with MOD.
IF 7 \ 2 <> 3 THEN PRINT "FAIL 7\2="; 7\2 : END
IF 15 \ 4 <> 3 THEN PRINT "FAIL 15\4="; 15\4 : END
IF -7 \ 2 <> -3 THEN PRINT "FAIL -7\2="; -7\2 : END
IF 100 \ 7 <> 14 THEN PRINT "FAIL 100\7="; 100\7 : END
IF (23 \ 8) * 8 + (23 MOD 8) <> 23 THEN PRINT "FAIL split" : END
IF 5 \ 0 <> 0 THEN PRINT "FAIL div0" : END
PRINT "OK"
END
