10 REM test GET# - write three bytes then read them back with GET#
20 OPEN 1,1,1,"GETTEST.DAT"
30 PRINT#1, "X";
40 PRINT#1, "Y";
50 PRINT#1, "Z"
60 CLOSE 1
70 OPEN 2,1,0,"GETTEST.DAT"
80 GET#2, A$
90 GET#2, B$
100 GET#2, C$
110 CLOSE 2
120 PRINT "A$='"; A$; "' B$='"; B$; "' C$='"; C$; "'"
130 IF A$="X" AND B$="Y" AND C$="Z" THEN PRINT "OK"
