10 REM skip_if_block: inline IF inside block IF THEN must not break END IF matching
20 IF 1=1 THEN
30   IF 0=1 THEN PRINT "BAD"
40 ELSE
50   PRINT "OK"
60 END IF
70 END
