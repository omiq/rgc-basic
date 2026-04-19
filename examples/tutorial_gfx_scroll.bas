' ============================================================
'  Tutorial: viewport SCROLL (camera-style pan in basic-gfx / canvas)
'  Run:  ./basic-gfx examples/tutorial_gfx_scroll.bas
'   or open web/canvas.html and load this file into the VFS.
'  SCROLL dx, dy moves the visible layer left/up by dx/dy pixels.
'  SCROLLX() / SCROLLY() return the current offset (see status line).
' ============================================================

COLOR 1
PRINT "{CLR}{HOME}SCROLL DEMO - watch text slide"
PRINT "SCROLL 16,0 pans one column (8px) to the right"
PRINT "SCROLL 0,8  pans one text row up"

' Pan right in small steps (8 px = one character cell)
FOR I = 1 TO 5
  SCROLL I * 8, 0
  TEXTAT 0, 24, "SCROLLX = " + STR$(SCROLLX())
  SLEEP 0.25
NEXT I

' Reset then pan down
SCROLL 0, 0
FOR J = 1 TO 3
  SCROLL 0, J * 8
  TEXTAT 0, 24, "SCROLLY = " + STR$(SCROLLY()) + "   "
  SLEEP 0.25
NEXT J

SCROLL 0, 0
PRINT
PRINT "Done - SCROLL 0,0 resets the view."
