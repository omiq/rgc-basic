1 REM ============================================================
2 REM Tutorial: tile sheet LOADSPRITE, DRAWSPRITETILE, SPRITEFRAME
3 REM Requires: examples/tutorial_tile_sheet_demo.png (16x8 = two 8x8 tiles)
4 REM Run: ./basic-gfx examples/tutorial_gfx_tilemap.bas
5 REM ============================================================
10 REM Two tiles: red (index 1) and green (index 2)
20 LOADSPRITE 0, "tutorial_tile_sheet_demo.png", 8, 8
30 PRINT "{CLR}{HOME}Tiles in sheet:"; SPRITETILES(0)
40 REM Draw tile 2 at pixel (100, 80), z=50
50 DRAWSPRITETILE 0, 100, 80, 2, 50
60 REM Set default frame for DRAWSPRITE (same as tile 1)
70 SPRITEFRAME 0, 1
80 DRAWSPRITE 0, 180, 80, 50
90 PRINT "SPRITEFRAME(0)="; SPRITEFRAME(0)
100 SLEEP 1
110 END
