' ============================================================
'  GFX CHARSET DEMO - show screen codes 0..255
'  Run:  ./basic-gfx examples/gfx_charset_demo.bas
'
'  Screen RAM starts at 1024 ($0400); colour RAM at 55296 ($D800).
'  Screen is 40x25 characters (1000 cells). This demo writes screen
'  codes 0..255 into the top of screen RAM so you can see how each
'  code is rendered by the built-in 8x8 font.
' ============================================================

OPTION CHARSET UPPER
BASE      = 1024
COLORBASE = 55296
W         = 40
CELLS     = W * 25           ' 1000
TOTAL     = 256

' Fill screen codes 0..255, then blank out the rest
FOR I = 0 TO TOTAL - 1
  POKE BASE + I, I
NEXT I
FOR I = TOTAL TO CELLS - 1
  POKE BASE + I, 32          ' space
NEXT I

' Colours: cycle the 16 C64 colours across all cells
FOR I = 0 TO CELLS - 1
  POKE COLORBASE + I, I - INT(I / 16) * 16
NEXT I

LOCATE 0, 15
PRINT "GFX CHARSET DEMO: SCREEN CODES 0..255"
PRINT "WINDOW WILL CLOSE IN 5 SECONDS..."
SLEEP 300
