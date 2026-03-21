1 REM Test 80-column and no-wrap options
2 REM Run: ./basic -columns 80 tests/columns_test.bas
10 PRINT "40-col default:"
20 FOR I=1 TO 40
30 PRINT "X";
40 NEXT I
50 PRINT "END"
60 PRINT
70 REM With -columns 80 the next line should wrap at 80
80 PRINT "80-col test (if -columns 80):"
90 FOR I=1 TO 80
100 PRINT "Y";
110 NEXT I
120 PRINT "END"
130 END
