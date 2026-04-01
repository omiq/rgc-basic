1 REM ============================================================
2 REM Tutorial: virtual memory bases for POKE/PEEK (C64-style layout)
3 REM Run: ./basic-gfx examples/tutorial_gfx_memory.bas
4 REM Default: screen $0400, color $D800, charset $3000, keys $DC00, bitmap $2000
5 REM Use #OPTION in a real project, or -memory on the command line.
6 REM ============================================================
10 REM --- Default screen RAM at 1024 (0x0400), same as C64 first screen line
20 POKE 1024, 32
30 POKE 1025, 32
40 REM White letter A (screencode 1) at top-left
50 POKE 1024, 1
60 POKE 55296, 1
70 REM Read back
80 PRINT "{CLR}{HOME}PEEK screen @1024 ="; PEEK(1024)
90 PRINT "PEEK colour @55296 ="; PEEK(55296)
100 PRINT
110 PRINT "Tip: #OPTION memory c64 | pet | default"
120 PRINT "     #OPTION screen 1024   (override base)"
130 END
