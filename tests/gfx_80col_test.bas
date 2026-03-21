1 REM GFX 80-column test - run: ./basic-gfx -columns 80 tests/gfx_80col_test.bas
2 REM Prints "80-COLUMN MODE" and fills a line with 80 chars
10 PRINT "80-COLUMN MODE"
20 FOR I=1 TO 80
30 PRINT "X";
40 NEXT I
50 PRINT
60 PRINT "If you see 80 X's on one line above, 80-col works."
70 SLEEP 180
80 END
