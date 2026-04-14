REM Regression: IF cond THEN <stmt-with-comma-args> : <stmt>
REM Bug: statement_poke's non-gfx fallback did *p += strlen(*p),
REM eating the trailing ': stmt' so it never ran. Fixed by parsing
REM and discarding the args properly. Other comma-arg statements
REM (LOCATE, COLOR, PRINT) were already correct; this test guards
REM POKE and exercises a few neighbours so any future regression
REM in the same shape is caught immediately.

X = 5

REM Case 1: one-arg statement before colon (control)
Z = 0
IF X = 5 THEN COLOR 7 : Z = 1
IF Z <> 1 THEN PRINT "FAIL: COLOR n + : stmt, Z=";Z : STOP

REM Case 2: two-arg statement before colon (LOCATE)
Z = 0
IF X = 5 THEN LOCATE 1, 1 : Z = 2
IF Z <> 2 THEN PRINT "FAIL: LOCATE r,c + : stmt, Z=";Z : STOP

REM Case 3: two-arg statement before colon (POKE - the original bug)
Z = 0
IF X = 5 THEN POKE 1024, 65 : Z = 3
IF Z <> 3 THEN PRINT "FAIL: POKE a,b + : stmt, Z=";Z : STOP

REM Case 4: false branch must still skip everything after THEN
Z = 0
IF X = 0 THEN POKE 1024, 65 : Z = 99
IF Z <> 0 THEN PRINT "FAIL: false IF leaked, Z=";Z : STOP

REM Case 5: print-list with commas before colon
Z = 0
IF X = 5 THEN PRINT 1, 2, 3 : Z = 5
IF Z <> 5 THEN PRINT "FAIL: PRINT list + : stmt, Z=";Z : STOP

PRINT "PASS"
