' CLR clears variables but keeps FUNCTION/DEF FN definitions

A = 1
B$ = "before"
PRINT "A = "; A; "   B$ = "; B$
CLR
PRINT "After CLR:  A = "; A; "   B$ = '"; B$; "'"
