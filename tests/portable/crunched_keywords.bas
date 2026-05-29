10 REM crunched CBM-style source must lint clean (normalize_keywords_line)
20 REM glued control-flow keywords the interpreter restores: IF FOR TO NEXT
30 REM GOTO THEN. (Digit-glued AND/OR are intentionally not restored, so
40 REM this fixture sticks to the forms that actually parse.)
50 T9=0
60 FORI=1TO5
70 R1=I*2
80 IFR1>4THENT9=T9+1
90 IFI=1THENGOTO110
100 T9=T9+10
110 NEXTI
120 PRINT T9
