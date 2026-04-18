REM KEYDOWN / KEYUP / KEYPRESS parse + dispatch test.
REM Headless-safe: terminal build has no key_state, so KEYDOWN/KEYPRESS
REM return 0 and KEYUP returns 1 (nothing is held). basic-gfx / canvas
REM WASM override with the real implementation.
FAILS = 0

REM 1. KEYDOWN of any code on terminal build must be 0.
A = KEYDOWN(ASC("W"))
IF A <> 0 THEN PRINT "FAIL 1 KEYDOWN terminal expected 0 got ";A : FAILS = FAILS + 1

REM 2. KEYUP of any code on terminal build must be 1.
B = KEYUP(ASC("W"))
IF B <> 1 THEN PRINT "FAIL 2 KEYUP terminal expected 1 got ";B : FAILS = FAILS + 1

REM 3. KEYPRESS of any code on terminal build must be 0 (no press events).
C = KEYPRESS(ASC("W"))
IF C <> 0 THEN PRINT "FAIL 3 KEYPRESS terminal expected 0 got ";C : FAILS = FAILS + 1

REM 4. Regression: parsing is order-independent — function-call position
REM    inside a larger expression.
D = 10 + KEYDOWN(ASC("Q")) * 5
IF D <> 10 THEN PRINT "FAIL 4 expected 10 got ";D : FAILS = FAILS + 1

IF FAILS > 0 THEN PRINT "KEYBOARD-INTRINSICS: ";FAILS;" failure(s)" : STOP
PRINT "KEYBOARD-INTRINSICS: all 4 cases passed"
END
