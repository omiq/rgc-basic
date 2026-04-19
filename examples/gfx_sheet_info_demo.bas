' ============================================================
'  gfx_sheet_info_demo - query loaded sheet metadata
'
'  Six accessors, all reading the same underlying sheet record.
'  Pick the one whose intent matches your code: SPRITE FRAMES for
'  animators, TILE COUNT for tilemap authors, SHEET * for grid geometry.
' ============================================================

SPRITE LOAD 0, "ship.png",       32, 32
SPRITE LOAD 1, "tile_sheet.png", 32, 32

PRINT "{CLR}SHEET METADATA"
PRINT "==============="
PRINT

PRINT "SLOT 0 (ship.png):"
PRINT "  SPRITE FRAMES = "; SPRITE FRAMES(0)
PRINT "  TILE COUNT    = "; TILE COUNT(0); "  (same number, tile intent)"
PRINT "  SHEET COLS    = "; SHEET COLS(0)
PRINT "  SHEET ROWS    = "; SHEET ROWS(0)
PRINT "  SHEET WIDTH   = "; SHEET WIDTH(0);  " px per cell"
PRINT "  SHEET HEIGHT  = "; SHEET HEIGHT(0); " px per cell"
PRINT

PRINT "SLOT 1 (tile_sheet.png):"
PRINT "  SPRITE FRAMES = "; SPRITE FRAMES(1)
PRINT "  TILE COUNT    = "; TILE COUNT(1)
PRINT "  SHEET COLS    = "; SHEET COLS(1)
PRINT "  SHEET ROWS    = "; SHEET ROWS(1)
PRINT "  SHEET WIDTH   = "; SHEET WIDTH(1);  " px per cell"
PRINT "  SHEET HEIGHT  = "; SHEET HEIGHT(1); " px per cell"
PRINT

PRINT "PRESS ANY KEY"
DO
  K$ = INKEY$()
  IF K$ <> "" THEN EXIT
  SLEEP 1
LOOP
