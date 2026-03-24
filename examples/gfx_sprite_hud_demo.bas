1 REM PNG HUD overlay: transparent panel over PETSCII text (basic-gfx)
2 REM From repo root: ./basic-gfx examples/gfx_sprite_hud_demo.bas
10 PRINT "{CLR}SPRITE HUD DEMO"
20 PRINT ""
30 PRINT "Semi-transparent PNG drawn on top (z=200)."
40 PRINT "Press a key or wait..."
50 LOADSPRITE 0,"hud_panel.png"
60 REM Crop: first 32x16 of sheet; place at (80,40); above text (z=200)
70 DRAWSPRITE 0,80,40,200,0,0,32,16
80 SLEEP 300
90 END
