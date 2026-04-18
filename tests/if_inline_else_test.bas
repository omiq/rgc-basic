REM Single-line IF ... THEN ... ELSE ... — verify inline ELSE routes correctly.
REM Each case sets an OUT variable and we compare to an expected value; any
REM mismatch prints a FAIL line and the program continues so the whole matrix
REM gets exercised. Final state is asserted by the summary line.

FAILS = 0

REM 1. cond true, single-statement THEN, single-statement ELSE.
X = 0
IF 1 = 1 THEN X = 10 ELSE X = 20
IF X <> 10 THEN PRINT "FAIL 1 expected 10 got ";X : FAILS = FAILS + 1

REM 2. cond false, single-statement THEN, single-statement ELSE.
Y = 0
IF 1 = 2 THEN Y = 10 ELSE Y = 20
IF Y <> 20 THEN PRINT "FAIL 2 expected 20 got ";Y : FAILS = FAILS + 1

REM 3. cond true, no ELSE — rest-of-line executes, no error.
Z = 0
IF 1 = 1 THEN Z = 7
IF Z <> 7 THEN PRINT "FAIL 3 expected 7 got ";Z : FAILS = FAILS + 1

REM 4. cond false, no ELSE — rest-of-line skipped.
W = 5
IF 1 = 2 THEN W = 99
IF W <> 5 THEN PRINT "FAIL 4 expected 5 got ";W : FAILS = FAILS + 1

REM 5. cond true, multi-statement THEN via ':' — all THEN statements run, ELSE half skipped.
A = 0 : B = 0
IF 1 = 1 THEN A = 1 : B = 2 ELSE A = 9 : B = 9
IF A <> 1 OR B <> 2 THEN PRINT "FAIL 5 A=";A;" B=";B : FAILS = FAILS + 1

REM 6. cond false, multi-statement THEN + multi-statement ELSE.
C = 0 : D = 0
IF 1 = 2 THEN C = 9 : D = 9 ELSE C = 3 : D = 4
IF C <> 3 OR D <> 4 THEN PRINT "FAIL 6 C=";C;" D=";D : FAILS = FAILS + 1

REM 7. Parenthesised arithmetic LHS with MOD in condition (regression for the
REM    "(expr) MOD n = 0" case that previously tripped Missing THEN).
REM    I=12 → 12*17+3 = 207 → 207 MOD 9 = 0.
I = 12
IF (I*17+3) MOD 9 = 0 THEN E = 1
IF E <> 1 THEN PRINT "FAIL 7 expected 1 got ";E : FAILS = FAILS + 1

REM 8. Same as 7 but with an ELSE branch; also exercises FALSE side.
J = 4
IF (J*17+3) MOD 9 = 0 THEN F = 1 ELSE F = 2
IF F <> 2 THEN PRINT "FAIL 8 expected 2 got ";F : FAILS = FAILS + 1

REM 9. ELSE inside a string literal must not be treated as keyword.
G$ = ""
IF 1 = 1 THEN G$ = "do ELSE ignored"
IF G$ <> "do ELSE ignored" THEN PRINT "FAIL 9 got ";G$ : FAILS = FAILS + 1

REM 10. Identifier ending in ELSE (e.g. CELSE) must not match the ELSE keyword.
CELSE = 42
H = 0
IF 1 = 1 THEN H = CELSE
IF H <> 42 THEN PRINT "FAIL 10 expected 42 got ";H : FAILS = FAILS + 1

REM 11. Block IF/ELSE/END IF must still work unchanged.
K = 0
IF 1 = 1 THEN
  K = 11
ELSE
  K = 22
END IF
IF K <> 11 THEN PRINT "FAIL 11 expected 11 got ";K : FAILS = FAILS + 1

L = 0
IF 1 = 2 THEN
  L = 11
ELSE
  L = 22
END IF
IF L <> 22 THEN PRINT "FAIL 12 expected 22 got ";L : FAILS = FAILS + 1

REM --- summary --------------------------------------------------------
IF FAILS > 0 THEN PRINT "IF-INLINE-ELSE: ";FAILS;" failure(s)" : STOP
PRINT "IF-INLINE-ELSE: all 12 cases passed"
END
