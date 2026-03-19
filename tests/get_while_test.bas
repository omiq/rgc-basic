1 REM GET in WHILE loop - test K$<>"Q" exit and Enter handling
2 REM Pipe: printf "ABC\nQ\n" | ./basic -petscii tests/get_while_test.bas
10 K$=""
20 WHILE K$ <> "Q"
30   IF K$<>"" THEN PRINT K$
40   GET K$
50 WEND
60 PRINT "DONE"
70 END
