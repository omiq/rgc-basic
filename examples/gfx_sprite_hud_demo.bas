1 REM PNG HUD overlay: DRAWSPRITE x,y are *pixel* coords (320x200), not text rows.
2 REM Row 0 is y=0..7, row 1 is y=8..15, etc. y=40 is row 5 — below several PRINT lines.
3 REM Run: ./basic-gfx examples/gfx_sprite_hud_demo.bas   (or add CHR$(14) for lowercase)
10 PRINT CHR$(14)
20 PRINT "{CLR}HUD DEMO: cyan panel should sit ON this line (see letters through it)."
30 PRINT ""
40 PRINT "Semi-transparent PNG (alpha). z=200 draws above PETSCII."
50 PRINT "Press a key or wait..."
60 LOADSPRITE 0,"hud_panel.png"
70 REM 32x16 crop; x=24 y=2 overlaps first line of text (chars are 8px tall)
80 DRAWSPRITE 0,24,2,200,0,0,32,16
90 REM UNLOADSPRITE 0 : REM optional — free slot before exit (textures also freed on close)
100 SLEEP 300
110 END
