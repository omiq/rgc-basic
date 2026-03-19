#!/usr/bin/env basic
# OPTION petscii
REM Delete a git tag vX.Y.Z locally and on origin

REM Check command line argument count
IF ARGC() = 0 THEN
    PRINT "{reverse on}Usage{reverse off}: delete-tag.bas <version>"
    PRINT "{reverse on}Example{reverse off}: delete-tag.bas 1.1.3"
ELSE 
    REM Do the delete command
    VER$ = ARG$(1)
    TAG$ = "v" + VER$
    PRINT "Deleting local tag "; TAG$
    CMD$ = "git tag -d " + TAG$
    RC = SYSTEM(CMD$)
    IF RC <> 0 THEN
        PRINT "Warning: local delete failed (exit "; RC; "). Tag may not exist."
    END IF
    PRINT "Deleting remote tag "; TAG$
    CMD$ = "git push origin --delete " + TAG$
    RC = SYSTEM(CMD$)
    IF RC <> 0 THEN
        PRINT "Error: remote delete failed (exit "; RC; "). Check origin and network."
        END
    END IF
    PRINT TAG$; " deleted."
END IF