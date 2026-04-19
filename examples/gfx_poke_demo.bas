' ============================================================
'  GFX POKE DEMO - write characters and colours to screen RAM
'  Run:  ./basic-gfx examples/gfx_poke_demo.bas
'  Screen RAM @ 1024 ($0400); colour RAM @ 55296 ($D800).
'  Screen is 40x25, row-major. Tutorial version of tests/gfx_poke_test.bas.
' ============================================================

SCR    = 1024
COLR   = 55296
WIDTH_ = 40

' --- "HELLO" at top-left (screen codes H=8 E=5 L=12 O=15) --------
POKE SCR + 0, 8
POKE SCR + 1, 5
POKE SCR + 2, 12
POKE SCR + 3, 12
POKE SCR + 4, 15

' Colour each letter differently (white, red, green, blue, yellow)
POKE COLR + 0, 1
POKE COLR + 1, 2
POKE COLR + 2, 5
POKE COLR + 3, 6
POKE COLR + 4, 7

' --- "WORLD" on the second row (row 1 = offset 40) ---------------
POKE SCR + WIDTH_ + 0, 23    ' W
POKE SCR + WIDTH_ + 1, 15    ' O
POKE SCR + WIDTH_ + 2, 18    ' R
POKE SCR + WIDTH_ + 3, 12    ' L
POKE SCR + WIDTH_ + 4, 4     ' D

FOR I = 0 TO 4
  POKE COLR + WIDTH_ + I, 3  ' cyan
NEXT I

' --- Red bar on row 4 (160 = 4 * 40) -----------------------------
FOR I = 0 TO 39
  POKE SCR  + 160 + I, 160   ' reversed space
  POKE COLR + 160 + I, 2     ' red
NEXT I

' --- "POKE WORKS!" centred on the red bar (col 14, row 4) --------
' P=16 O=15 K=11 E=5 space=32 W=23 O=15 R=18 K=11 S=19 !=33
DATA 16, 15, 11, 5, 32, 23, 15, 18, 11, 19, 33
FOR I = 0 TO 10
  READ CODE
  POKE SCR  + 160 + 14 + I, CODE
  POKE COLR + 160 + 14 + I, 1   ' white on red
NEXT I

' --- PEEK test: read back first screen byte ----------------------
A = PEEK(SCR)
LOCATE 0, 10
PRINT "PEEK("; SCR; ") = "; A; " (expected 8 for H)"
PRINT
PRINT "GFX POKE DEMO COMPLETE - closing in 5 seconds..."
SLEEP 300
