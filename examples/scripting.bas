' Shell-scripting style example: ARGC/ARG$, SYSTEM(), EXEC$()
' Run:  ./basic examples/scripting.bas [args...]
' Or:   ./basic examples/scripting.bas "hello world"

PRINT "Program:   "; ARG$(0)
PRINT "Arguments: "; ARGC()

FOR I = 1 TO ARGC()
  PRINT "  "; I; ": "; ARG$(I)
NEXT I

IF ARGC() < 1 THEN
  PRINT "Usage: basic scripting.bas [name]"
  END
END IF

PRINT
PRINT "Hello, "; ARG$(1); "!"
PRINT

' Run a command and get its exit code
E = SYSTEM("date")
PRINT "Exit code of date: "; E

' Run a command and capture its stdout
O$ = EXEC$("whoami")
PRINT "User: "; O$
O$ = EXEC$("echo OK")
PRINT "Echo says: "; O$
