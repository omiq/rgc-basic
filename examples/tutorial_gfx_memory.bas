' ============================================================
'  Tutorial: virtual memory bases for POKE/PEEK (C64-style layout)
'  Run: ./basic-gfx examples/tutorial_gfx_memory.bas
'  Default map: screen $0400, colour $D800, charset $3000,
'               keys $DC00, bitmap $2000.
'  Use #OPTION in a real project, or -memory on the command line.
' ============================================================

' Default screen RAM at 1024 ($0400) - same as C64 first screen line
POKE 1024, 32
POKE 1025, 32

' White letter A (screencode 1) at top-left
POKE 1024, 1
POKE 55296, 1

' Read it back
PRINT "{CLR}{HOME}PEEK screen  @1024  = "; PEEK(1024)
PRINT "PEEK colour  @55296 = "; PEEK(55296)
PRINT
PRINT "Tip: #OPTION memory c64 | pet | default"
PRINT "     #OPTION screen 1024       (override base)"
