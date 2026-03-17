5 REM Delete a git tag vX.Y.Z locally and on origin
10 IF ARGC() <> 1 THEN GOTO 40

20 VER$ = ARG$(1)
30 GOTO 70

40 PRINT "Usage: delete-tag.bas <version>"
50 PRINT "Example: delete-tag.bas 1.1.3"
60 END

70 TAG$ = "v" + VER$
80 PRINT "Deleting local tag "; TAG$
90 CMD$ = "git tag -d " + TAG$
100 RC = SYSTEM(CMD$)
110 PRINT "SYSTEM returned "; RC

120 PRINT "Deleting remote tag "; TAG$
130 CMD$ = "git push origin --delete " + TAG$
140 RC = SYSTEM(CMD$)
150 PRINT "SYSTEM returned "; RC

160 END
