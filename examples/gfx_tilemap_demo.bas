' ============================================================
'  gfx_tilemap_demo - batched tile grid via TILEMAP DRAW
'
'  Replaces a 70-call per-frame loop with ONE interpreter
'  dispatch; the runtime iterates the map array in C.
'
'  Asset: tile_sheet.png (64x32 = two 32x32 cells)
'    index 1 = healthy, index 2 = damaged.
'
'  Layout: top 3 text rows + 5 tile rows (160 px) + bottom text
'  row. That leaves room for status without tiles covering it.
'
'  Keys: SPACE damage random cell, R reset, Q quit
' ============================================================

PRINT CHR$(14)
SPRITE LOAD 0, "tile_sheet.png", 32, 32

COLS = 10 : ROWS = 5
TY   = 24

DIM MAP(COLS * ROWS - 1)
FOR I = 0 TO COLS * ROWS - 1 : MAP(I) = 1 : NEXT I

DO
  K$ = UCASE$(INKEY$())
  IF K$ = "Q" THEN EXIT
  IF K$ = "R" THEN
    FOR I = 0 TO COLS * ROWS - 1 : MAP(I) = 1 : NEXT I
  END IF
  IF K$ = " " THEN MAP(INT(RND(1) * COLS * ROWS)) = 2

  CLS
  PRINT "{HOME}TILEMAP DEMO - SHEET HAS "; TILE COUNT(0); " TILES"
  TILEMAP DRAW 0, 0, TY, COLS, ROWS, MAP()
  LOCATE 1, 24
  PRINT "SPACE = damage  R = reset  Q = quit";
  VSYNC
LOOP
