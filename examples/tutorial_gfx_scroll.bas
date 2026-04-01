1 REM ============================================================
2 REM Tutorial: viewport SCROLL (camera-style pan in basic-gfx / canvas)
3 REM Run: ./basic-gfx examples/tutorial_gfx_scroll.bas
4 REM   or open web/canvas.html and load this file into the VFS.
5 REM SCROLL dx, dy moves the visible layer left/up by dx, dy pixels.
6 REM SCROLLX() / SCROLLY() return the current offset (see status line).
7 REM ============================================================
10 REM Draw a label so you can see the screen shift
20 COLOR 1
30 PRINT "{CLR}{HOME}SCROLL DEMO — watch text slide"
40 PRINT "SCROLL 16,0 pans one column (8px) to the right"
50 PRINT "SCROLL 0,8 pans one text row up"
60 REM Pan right in small steps (8 px = one character cell)
70 FOR I = 1 TO 5
80 SCROLL I * 8, 0
90 TEXTAT 0, 24, "SCROLLX=" + STR$(SCROLLX())
100 SLEEP 0.25
110 NEXT I
120 REM Reset then pan down
130 SCROLL 0, 0
140 FOR J = 1 TO 3
150 SCROLL 0, J * 8
160 TEXTAT 0, 24, "SCROLLY=" + STR$(SCROLLY()) + "   "
170 SLEEP 0.25
180 NEXT J
190 SCROLL 0, 0
200 PRINT
210 PRINT "Done — SCROLL 0,0 resets the view."
220 END
