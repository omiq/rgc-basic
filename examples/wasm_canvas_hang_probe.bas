REM --- Paste into canvas.html; click canvas before GET tests ---
REM --- Use Stop if a phase hangs; note which phase in bug reports ---

REM Phase A: GET echo (one key per line; should NOT skip prompts)
REM 10 PRINT "PHASE A: type 3 keys (e.g. a b c), each should print once"
REM 20 GET K$
REM 30 IF K$="" THEN 20
REM 40 PRINT K$
REM 50 GOTO 20

REM Phase B: MID$ storm (similar workload to trek SRS inner loop)
10 PRINT "PHASE B: MID$ x2000 — should finish without freezing"
20 Q$=STRING$(200,"x")
30 FOR I=1 TO 2000
40 A$=MID$(Q$,1,1)
50 NEXT I
60 PRINT "OK B"
70 END

REM Phase C: STRING$ + PRINT (gfx_put_byte yields)
REM 10 PRINT "PHASE C: long PRINT"
REM 20 PRINT STRING$(3000,".")
REM 30 PRINT "OK C"
REM 40 END

REM Phase D: tight FOR no PRINT (statement-level yields only)
REM 10 PRINT "PHASE D: FOR 2M POKE only"
REM 20 FOR I=1 TO 2000000
REM 30 POKE 1024,(I AND 255)
REM 40 NEXT I
REM 50 PRINT "OK D"
REM 60 END

REM Phase E: trek-style GET loop (press RETURN to exit)
REM 10 PRINT "PHASE E: press RETURN once to continue"
REM 20 GET K$
REM 30 IF K$="" THEN 20
REM 40 IF ASC(K$)<>13 THEN 20
REM 50 PRINT "OK E"
REM 60 END
