' ============================================================
'  gfx_screen2_print_demo - PRINT in SCREEN 2
'
'  PRINT works in every SCREEN mode now:
'    SCREEN 0 - writes to the text plane (PETSCII)
'    SCREEN 1 - stamps 8x8 glyph into 1bpp bitmap + colour plane
'    SCREEN 2 - stamps 8x8 glyph into RGBA plane
'
'  Cursor grid is 40x25 cells in every mode. PRINT auto-wraps
'  and scrolls on overflow, same as text mode. Use DRAWTEXT for
'  pixel-space stamps with arbitrary (x, y) + scale.
'
'  Keys: Q quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 0, 20, 40
CLS

COLORRGB 200, 230, 255
PRINT "PRINT IN SCREEN 2"
PRINT
PRINT "CELL-GRID LAYOUT LIKE TEXT MODE"
PRINT "AUTO-WRAP + SCROLL ON OVERFLOW"
PRINT

FOR I = 1 TO 16
  COLOR I - 1                    ' cycle palette - each row its own colour
  PRINT "ROW "; I; " - COLOR "; I - 1
NEXT I

PRINT
COLORRGB 255, 220, 0
PRINT "Q = QUIT"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 1
LOOP
