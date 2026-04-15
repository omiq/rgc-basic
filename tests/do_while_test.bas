REM DO WHILE tests

REM 1. Basic count
I = 1
DO WHILE I <= 3
    PRINT I
    I = I + 1
LOOP
REM expect 1 2 3

REM 2. False on entry -- body must not execute
J = 99
DO WHILE J < 0
    PRINT "FAIL"
LOOP
PRINT "J="; J
REM expect J= 99

REM 3. Existing DO LOOP UNTIL unaffected
K = 0
DO
    K = K + 1
LOOP UNTIL K = 3
PRINT "K="; K
REM expect K= 3

REM 4. Nested DO WHILE
A = 1
DO WHILE A <= 2
    B = 10
    DO WHILE B <= 11
        PRINT A; B
        B = B + 1
    LOOP
    A = A + 1
LOOP
REM expect 1 10 / 1 11 / 2 10 / 2 11

REM 5. EXIT inside DO WHILE
N = 0
DO WHILE N < 100
    N = N + 1
    IF N = 5 THEN EXIT
LOOP
PRINT "N="; N
REM expect N= 5

PRINT "OK"
