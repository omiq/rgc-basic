' ============================================================
'  PNG HUD overlay demo.
'  DRAWSPRITE x,y are *pixel* coords on the 320x200 canvas - NOT
'  text rows. Row 0 = y 0..7, row 1 = y 8..15, ... y=40 is row 5,
'  i.e. below several PRINT lines.
'  Run:  ./basic-gfx examples/gfx_sprite_hud_demo.bas
' ============================================================

PRINT CHR$(14)                                  ' lowercase charset
PRINT "{CLR}HUD DEMO: cyan panel sits ON this line (see letters through it)."
PRINT
PRINT "Semi-transparent PNG (alpha). z=200 draws above PETSCII."
PRINT "Press a key or wait..."

LOADSPRITE 0, "hud_panel.png"
' 32x16 crop; x=24 y=2 overlaps the first line of text (chars are 8px tall)
DRAWSPRITE 0, 24, 2, 200, 0, 0, 32, 16

' UNLOADSPRITE 0   ' optional - slots are freed automatically on exit

SLEEP 300
