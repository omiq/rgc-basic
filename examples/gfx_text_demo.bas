' ============================================================
'  GFX TEXT DEMO - PRINT / LOCATE / TEXTAT / CHR$ / {TOKENS} / COLOR / BACKGROUND
'  Run:  ./basic-gfx -petscii examples/gfx_text_demo.bas
'   (In gfx mode -petscii keeps token expansion on; CHR$ stays raw.)
' ============================================================

BACKGROUND 6
COLOR 14
PRINT "{CLR}{WHITE}RGC-BASIC GFX TEXT DEMO"
PRINT "{CYAN}PRINT + {YELLOW}TOKENS{CYAN} + {GREEN}COLOUR"
PRINT

COLOR 7
PRINT "THIS IS YELLOW VIA COLOR"
PRINT CHR$(28); "THIS IS RED VIA {RED} TOKEN CODE"
PRINT CHR$(146); "REVERSE OFF (FONT HAS INVERTED HALF)"
PRINT CHR$(18); "REVERSE ON"; CHR$(146); "  (TOGGLE)"

COLOR 3
LOCATE 0, 10
PRINT "LOCATE TO (0,10)"

TEXTAT 5, 12, "TEXTAT(5,12): {LIGHT BLUE}HELLO"
TEXTAT 5, 14, CHR$(159) + "CYAN VIA CHR$(159)"

COLOR 1
TEXTAT 0, 22, "PRESS ESC TO CLOSE WINDOW (OR WAIT 5S)"
SLEEP 300
