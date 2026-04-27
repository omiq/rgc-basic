' ============================================================
'  map_editor - RGC-BASIC port of the QB64 map-editor demo
'
'  Demonstrates SCREEN 4 (640x400 RGBA) for a desktop-style UI:
'  toolbar buttons, tile picker, map grid, mouse paint, plus
'  JSON file SAVE / LOAD against the canonical map format
'  (docs/map-format.md v1).
'
'  Tile graphics come from walls.png grid of
'  32x32 cells -> TILEMAP DRAW; 0 = blank).
'
'  Render model: full-frame redraw. CLS each tick wipes both the
'  bitmap plane and the per-frame TILEMAP cell list (cap 4096),
'  so continuous paint can never overflow it.
'
'  Save format: writes a v1 map.json file via PRINT# — a 10x10
'  bg tile layer, no objects, no camera. Load uses the runtime's
'  MAPLOAD statement, which validates schema and fills MAP_BG().
' ============================================================

SCREEN 4
DOUBLEBUFFER ON
BACKGROUNDRGB 32, 32, 48
CLS

SPRITE LOAD 0, "walls.png", 32, 32

TOOLBAR_H = 32
TILE_SIZE = 32

' Picker: grid of the loaded sheet tiles.
PCOLS = 8
PROWS = 4
PICK_COUNT = PCOLS * PROWS
PICKER_X = 8
PICKER_Y = TOOLBAR_H + 16

' Map grid.
MCOLS = 10
MROWS = 10
MAP_COUNT = MCOLS * MROWS
MAP_X = 280
MAP_Y = TOOLBAR_H + 16

BTN_LOAD_X0 = 8   : BTN_LOAD_Y0 = 4 : BTN_LOAD_X1 = 64  : BTN_LOAD_Y1 = 24
BTN_SAVE_X0 = 72  : BTN_SAVE_Y0 = 4 : BTN_SAVE_X1 = 128 : BTN_SAVE_Y1 = 24
BTN_QUIT_X0 = 592 : BTN_QUIT_Y0 = 4 : BTN_QUIT_X1 = 632 : BTN_QUIT_Y1 = 24

DIM PICKER(PICK_COUNT)
DIM MAP(MAP_COUNT)
' MAPLOAD targets — pre-DIMmed at MAP_COUNT so a JSON read fills
' MAP_BG and we copy back into MAP(). Other MAP_* arrays exist so
' MAPLOAD's writes don't crash on missing globals.
DIM MAP_BG(MAP_COUNT - 1)
DIM MAP_FG(MAP_COUNT - 1)
DIM MAP_COLL(15)
DIM MAP_OBJ_TYPE$(15)
DIM MAP_OBJ_KIND$(15)
DIM MAP_OBJ_X(15)
DIM MAP_OBJ_Y(15)
DIM MAP_OBJ_W(15)
DIM MAP_OBJ_H(15)
DIM MAP_OBJ_ID(15)
DIM MAP_TILESET_ID$(7)
DIM MAP_TILESET_SRC$(7)
SELECTED = 1
Q$ = CHR$(34)

' Status line state — re-stamped every frame after CLS.
STATUS$ = "LEFT CLICK A TILE, THEN LEFT CLICK + DRAG ON THE MAP. RIGHT CLICK CLEARS."
STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 220

' TILEMAP DRAW indices are 1-based; 0 = blank tile.
FOR I = 0 TO PICK_COUNT - 1
  PICKER(I) = I + 1
NEXT I

' Map starts blank.
FOR I = 0 TO MAP_COUNT - 1
  MAP(I) = 0
NEXT I

' Bitmap-plane chrome only drawn once — TILEMAP CLEAR doesn't wipe it.
DrawChrome()

PREV_L = 0
PREV_R = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  MX = GETMOUSEX()
  MY = GETMOUSEY()
  L  = ISMOUSEBUTTONDOWN(0)
  R  = ISMOUSEBUTTONDOWN(1)

  ' --- input: edge-triggered clicks (buttons + picker) ---
  IF L = 1 AND PREV_L = 0 THEN
    IF MX >= BTN_QUIT_X0 AND MX <= BTN_QUIT_X1 AND MY >= BTN_QUIT_Y0 AND MY <= BTN_QUIT_Y1 THEN EXIT

    IF MX >= BTN_SAVE_X0 AND MX <= BTN_SAVE_X1 AND MY >= BTN_SAVE_Y0 AND MY <= BTN_SAVE_Y1 THEN
      SaveMapJson()
      STATUS$ = "SAVED map.json"
      STATUS_R = 200 : STATUS_G = 255 : STATUS_B = 200
    END IF

    IF MX >= BTN_LOAD_X0 AND MX <= BTN_LOAD_X1 AND MY >= BTN_LOAD_Y0 AND MY <= BTN_LOAD_Y1 THEN
      LoadMapJson()
    END IF

    IF MX >= PICKER_X AND MX < PICKER_X + PCOLS * TILE_SIZE AND MY >= PICKER_Y AND MY < PICKER_Y + PROWS * TILE_SIZE THEN
      CX = (MX - PICKER_X) \ TILE_SIZE
      CY = (MY - PICKER_Y) \ TILE_SIZE
      NEW_SEL = CY * PCOLS + CX + 1
      IF NEW_SEL >= 1 AND NEW_SEL <= PICK_COUNT THEN
        SELECTED = NEW_SEL
        STATUS$ = "SELECTED TILE " + STR$(SELECTED)
        STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 220
      END IF
    END IF
  END IF

  ' --- continuous paint: left-drag stamps SELECTED into MAP() ---
  IF L = 1 AND MX >= MAP_X AND MX < MAP_X + MCOLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + MROWS * TILE_SIZE THEN
    CX = (MX - MAP_X) \ TILE_SIZE
    CY = (MY - MAP_Y) \ TILE_SIZE
    IDX = CY * MCOLS + CX
    IF IDX >= 0 AND IDX < MAP_COUNT THEN MAP(IDX) = SELECTED
  END IF

  ' --- right-drag erases ---
  IF R = 1 AND MX >= MAP_X AND MX < MAP_X + MCOLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + MROWS * TILE_SIZE THEN
    CX = (MX - MAP_X) \ TILE_SIZE
    CY = (MY - MAP_Y) \ TILE_SIZE
    IDX = CY * MCOLS + CX
    IF IDX >= 0 AND IDX < MAP_COUNT THEN MAP(IDX) = 0
  END IF

  ' --- render: rebuild sprite layer from state ---
  ' TILEMAP CLEAR drops the per-frame cell list (cap 4096) without
  ' touching the bitmap plane, so toolbar/buttons drawn via FILLRECT
  ' don't have to be redrawn every tick. Picker / map FILLRECTs
  ' below cover their own area before re-stamping tiles.
  TILEMAP CLEAR
  DrawPicker()
  DrawMap()
  DrawHighlight()
  DrawStatus()

  PREV_L = L
  PREV_R = R
  VSYNC
LOOP
END

FUNCTION DrawChrome()
  COLORRGB 56, 56, 80  : FILLRECT 0, 0 TO 639, TOOLBAR_H - 1
  COLORRGB 160, 160, 200 : LINE 0, TOOLBAR_H - 1 TO 639, TOOLBAR_H - 1
  COLORRGB 80, 80, 96
  FILLRECT BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
  FILLRECT BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
  FILLRECT BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
  COLORRGB 200, 200, 220
  RECT BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
  RECT BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
  RECT BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
  COLORRGB 255, 255, 255
  DRAWTEXT BTN_LOAD_X0 + 8, BTN_LOAD_Y0 + 8, "LOAD"
  DRAWTEXT BTN_SAVE_X0 + 8, BTN_SAVE_Y0 + 8, "SAVE"
  DRAWTEXT BTN_QUIT_X0 + 4, BTN_QUIT_Y0 + 8, "QUIT"
  COLORRGB 220, 220, 220
  DRAWTEXT PICKER_X, PICKER_Y - 12, "TILE PICKER"
  DRAWTEXT MAP_X,    MAP_Y    - 12, "MAP"
END FUNCTION

FUNCTION DrawPicker()
  COLORRGB 24, 24, 32
  FILLRECT PICKER_X - 2, PICKER_Y - 2 TO PICKER_X + PCOLS * TILE_SIZE + 1, PICKER_Y + PROWS * TILE_SIZE + 1
  TILEMAP DRAW 0, PICKER_X, PICKER_Y, PCOLS, PROWS, PICKER()
  COLORRGB 80, 80, 100
  FOR I = 0 TO PICK_COUNT - 1
    GX = PICKER_X + (I MOD PCOLS) * TILE_SIZE
    GY = PICKER_Y + (I \ PCOLS) * TILE_SIZE
    RECT GX, GY TO GX + TILE_SIZE - 1, GY + TILE_SIZE - 1
  NEXT I
END FUNCTION

FUNCTION DrawMap()
  COLORRGB 16, 16, 24
  FILLRECT MAP_X - 2, MAP_Y - 2 TO MAP_X + MCOLS * TILE_SIZE + 1, MAP_Y + MROWS * TILE_SIZE + 1
  TILEMAP DRAW 0, MAP_X, MAP_Y, MCOLS, MROWS, MAP()
  COLORRGB 80, 80, 100
  FOR I = 0 TO MAP_COUNT - 1
    GX = MAP_X + (I MOD MCOLS) * TILE_SIZE
    GY = MAP_Y + (I \ MCOLS) * TILE_SIZE
    RECT GX, GY TO GX + TILE_SIZE - 1, GY + TILE_SIZE - 1
  NEXT I
END FUNCTION

FUNCTION DrawHighlight()
  HCX = (SELECTED - 1) MOD PCOLS
  HCY = (SELECTED - 1) \ PCOLS
  HX = PICKER_X + HCX * TILE_SIZE
  HY = PICKER_Y + HCY * TILE_SIZE
  COLORRGB 255, 255, 0
  RECT HX - 1, HY - 1 TO HX + TILE_SIZE, HY + TILE_SIZE
  RECT HX - 2, HY - 2 TO HX + TILE_SIZE + 1, HY + TILE_SIZE + 1
END FUNCTION

FUNCTION DrawStatus()
  COLORRGB 32, 32, 48 : FILLRECT 0, 376 TO 639, 399
  COLORRGB STATUS_R, STATUS_G, STATUS_B
  DRAWTEXT 8, 384, STATUS$
END FUNCTION

' ------------------------------------------------------------
'  JSON save / load — canonical map format v1
' ------------------------------------------------------------

FUNCTION SaveMapJson()
  ' Writes a v1 map.json: format/size/tileSize/tilesets/layers[bg].
  ' No object layer, no camera — this editor only paints a tile grid.
  OPEN 1, 1, 1, "map.json"
  PRINT#1, "{"
  PRINT#1, "  " + Q$ + "format" + Q$ + ": 1,"
  PRINT#1, "  " + Q$ + "id" + Q$ + ": " + Q$ + "editor-map" + Q$ + ","
  PRINT#1, "  " + Q$ + "size" + Q$ + ": { " + Q$ + "cols" + Q$ + ": " + STR$(MCOLS) + ", " + Q$ + "rows" + Q$ + ": " + STR$(MROWS) + " },"
  PRINT#1, "  " + Q$ + "tileSize" + Q$ + ": { " + Q$ + "w" + Q$ + ": 32, " + Q$ + "h" + Q$ + ": 32 },"
  PRINT#1, "  " + Q$ + "tilesets" + Q$ + ": ["
  PRINT#1, "    { " + Q$ + "id" + Q$ + ": " + Q$ + "walls" + Q$ + ", " + Q$ + "src" + Q$ + ": " + Q$ + "walls.png" + Q$ + ", " + Q$ + "cellW" + Q$ + ": 32, " + Q$ + "cellH" + Q$ + ": 32 }"
  PRINT#1, "  ],"
  PRINT#1, "  " + Q$ + "layers" + Q$ + ": ["
  PRINT#1, "    { " + Q$ + "name" + Q$ + ": " + Q$ + "bg" + Q$ + ", " + Q$ + "type" + Q$ + ": " + Q$ + "tiles" + Q$ + ", " + Q$ + "tilesetId" + Q$ + ": " + Q$ + "walls" + Q$ + ","
  PRINT#1, "      " + Q$ + "data" + Q$ + ": ["
  FOR SI = 0 TO MAP_COUNT - 1
    IF SI < MAP_COUNT - 1 THEN
      PRINT#1, "        " + STR$(MAP(SI)) + ","
    ELSE
      PRINT#1, "        " + STR$(MAP(SI))
    END IF
  NEXT SI
  PRINT#1, "      ]"
  PRINT#1, "    }"
  PRINT#1, "  ]"
  PRINT#1, "}"
  CLOSE #1
END FUNCTION

FUNCTION LoadMapJson()
  ' Probe for the file first — MAPLOAD raises a runtime error on a
  ' missing path, which would kill the editor. ST=1 after OPEN signals
  ' "not found"; bail out with a friendly status instead.
  OPEN 1, 1, 0, "map.json"
  IF ST = 1 THEN
    STATUS$ = "NO map.json YET - SAVE FIRST"
    STATUS_R = 255 : STATUS_G = 200 : STATUS_B = 200
    RETURN 0
  END IF
  CLOSE #1
  MAPLOAD "map.json"
  IF MAP_W = MCOLS AND MAP_H = MROWS THEN
    FOR LI = 0 TO MAP_COUNT - 1
      MAP(LI) = MAP_BG(LI)
    NEXT LI
    STATUS$ = "LOADED map.json"
    STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 255
  ELSE
    STATUS$ = "MAP SIZE MISMATCH - EXPECTED " + STR$(MCOLS) + "x" + STR$(MROWS)
    STATUS_R = 255 : STATUS_G = 200 : STATUS_B = 200
  END IF
END FUNCTION
