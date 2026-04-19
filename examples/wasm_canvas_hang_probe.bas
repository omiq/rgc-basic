' Canvas-WASM hang probe — runs tight string work that has previously
' stalled the browser main thread. Should finish with "OK B" on every build.
' Paste into canvas.html and click Run. If it freezes, note the phase
' in the bug report; other phases are kept commented below for quick triage.

' --- Phase B: MID$ x2000 — exercises the trek-style SRS inner loop ---
PRINT "PHASE B: MID$ x2000 - should finish without freezing"
Q$ = STRING$(200, "x")
FOR I = 1 TO 2000
  A$ = MID$(Q$, 1, 1)
NEXT I
PRINT "OK B"

' --- Alternative phases (uncomment one at a time to triage) ------------

' ' Phase A: GET echo (one key per line; should NOT skip prompts)
' PRINT "PHASE A: type 3 keys (e.g. a b c), each should print once"
' DO
'   GET K$
'   IF K$ <> "" THEN PRINT K$
'   SLEEP 1
' LOOP

' ' Phase B2: string concat like trek GOSUB 5440 (LEFT$ + A$ + RIGHT$)
' Q$ = STRING$(190, " ")
' A$ = "   "
' FOR I = 1 TO 400
'   Q$ = LEFT$(Q$, 80) + A$ + RIGHT$(Q$, 107)
' NEXT I
' PRINT "OK B2"

' ' Phase C: STRING$ + PRINT (gfx_put_byte yields)
' PRINT "PHASE C: long PRINT"
' PRINT STRING$(3000, ".")
' PRINT "OK C"

' ' Phase D: tight FOR with no PRINT (statement-level yields only)
' PRINT "PHASE D: FOR 2M POKE only"
' FOR I = 1 TO 2000000
'   POKE 1024, (I AND 255)
' NEXT I
' PRINT "OK D"

' ' Phase E: trek-style GET loop (press RETURN to exit)
' PRINT "PHASE E: press RETURN once to continue"
' DO
'   GET K$
'   IF K$ <> "" AND ASC(K$) = 13 THEN EXIT
'   SLEEP 1
' LOOP
' PRINT "OK E"
