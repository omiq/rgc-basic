' ============================================================
'  Tutorial: tile sheet - LOADSPRITE (w,h), DRAWSPRITETILE, SPRITEFRAME
'  Requires: examples/tutorial_tile_sheet_demo.png (16x8 = two 8x8 tiles)
'  Run:  ./basic-gfx examples/tutorial_gfx_tilemap.bas
' ============================================================

' Two tiles: red (index 1) and green (index 2)
LOADSPRITE 0, "tutorial_tile_sheet_demo.png", 8, 8
PRINT "{CLR}{HOME}Tiles in sheet: "; SPRITETILES(0)

' Draw tile 2 at pixel (100, 80) with z = 50
DRAWSPRITETILE 0, 100, 80, 2, 50

' Set the default frame for DRAWSPRITE (same as tile 1)
SPRITEFRAME 0, 1
DRAWSPRITE 0, 180, 80, 50
PRINT "SPRITEFRAME(0) = "; SPRITEFRAME(0)

SLEEP 1
