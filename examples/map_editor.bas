' ============================================================
'  map_editor - SCREEN 4 desktop-style map editor (v1.1)
'
'  Paints tiles from a tilesheet onto a JSON map file in the
'  canonical map format (docs/map-format.md v1). Loads any preset
'  map at runtime (RPG overworld, RPG cave, shooter stage 1, the
'  editor's own map.json) and saves back to the same path.
'
'  Toolbar:  [LOAD] [SAVE] [<] [>] <path>     [QUIT]
'  Picker:   tilesheet for the loaded map (0 = blank, 1..N = tiles).
'  Map:      VIEW_COLS x VIEW_ROWS slice of the full map; pan with
'            arrow keys when MCOLS / MROWS exceeds the viewport.
'  Mouse:    LEFT click a picker tile, then LEFT-drag on the map
'            to paint, RIGHT-drag erases.
'  Quit:     Q / ESC / [QUIT] button.
'
'  Render model: full-frame redraw. CLS / TILEMAP CLEAR each tick;
'  toolbar bitmap chrome stays put because we only redraw the
'  status bar + path text in the dynamic header band.
' ============================================================

' Asset literals used here so the IDE asset preloader scans them
' into MEMFS at run time, even when SPRITE LOAD is dynamic:
'   walls.png / rpg/Overworld_mini.png / rpg/cave_mini.png /
'   shooter/walls.png / rpg/level1_overworld.json / rpg/level1_cave.json /
'   shooter/level1.json
DIM ASSET_HINT$(6)
ASSET_HINT$(0) = "walls.png"
ASSET_HINT$(1) = "rpg/Overworld_mini.png"
ASSET_HINT$(2) = "rpg/cave_mini.png"
ASSET_HINT$(3) = "shooter/walls.png"
ASSET_HINT$(4) = "rpg/level1_overworld.json"
ASSET_HINT$(5) = "rpg/level1_cave.json"
ASSET_HINT$(6) = "shooter/level1.json"

SCREEN 4
DOUBLEBUFFER ON
BACKGROUNDRGB 32, 32, 48
CLS

' --- map storage caps (covers shooter 10x100 = 1000 cells and RPG
'     overworld 32x32 = 1024 cells; pick a comfortable upper bound).
MAP_CAP = 4096
DIM MAP(MAP_CAP - 1)

' MAPLOAD targets — pre-DIMmed at MAP_CAP so any preset fits.
DIM MAP_BG(MAP_CAP - 1)
DIM MAP_FG(MAP_CAP - 1)
DIM MAP_COLL(31)
DIM MAP_OBJ_TYPE$(63)
DIM MAP_OBJ_KIND$(63)
DIM MAP_OBJ_X(63)
DIM MAP_OBJ_Y(63)
DIM MAP_OBJ_W(63)
DIM MAP_OBJ_H(63)
DIM MAP_OBJ_ID(63)
DIM MAP_TILESET_ID$(7)
DIM MAP_TILESET_SRC$(7)

' Preset cycle list — order = display order. Path is the value
' passed to MAPLOAD (relative to MEMFS root).
PRESET_COUNT = 4
DIM PRESET_PATH$(PRESET_COUNT - 1)
PRESET_PATH$(0) = "map.json"
PRESET_PATH$(1) = "rpg/level1_overworld.json"
PRESET_PATH$(2) = "rpg/level1_cave.json"
PRESET_PATH$(3) = "shooter/level1.json"
PRESET_IDX = 0
CURRENT_MAP$ = PRESET_PATH$(PRESET_IDX)

' Mutable map shape — replaced on each Load.
TILE_SIZE = 32
MCOLS = 10
MROWS = 10
MAP_COUNT = MCOLS * MROWS
TILESET_SRC$ = "walls.png"
TILESET_DIR$ = ""

' Editor window into the map (cells, not pixels).
WIN_PX_W = 320
WIN_PX_H = 320
VIEW_COLS = WIN_PX_W \ TILE_SIZE
VIEW_ROWS = WIN_PX_H \ TILE_SIZE
CAM_COL = 0
CAM_ROW = 0

' UI layout — picker on the left, map window on the right.
TOOLBAR_H = 32
HEADER_BAND_Y = TOOLBAR_H
HEADER_BAND_H = 16
PICKER_X = 8
PICKER_Y = TOOLBAR_H + HEADER_BAND_H + 4
MAP_X = 280
MAP_Y = TOOLBAR_H + HEADER_BAND_H + 4

PCOLS = 8
DIM PICKER(127)            ' up to 128 tiles in current page
PICK_COUNT = 32
PROWS = 4
PAGE = 0

' Staging buffer for the viewport-into-MAP() slice that DrawMap
' hands to TILEMAP DRAW. Sized at the largest VIEW_COLS * VIEW_ROWS
' the editor will ever render — 320/16 * 320/16 = 400 cells.
DIM VIEW_BUF(511)

' Pan repeat-rate state for HandlePan(). PAN_HOLD records that an
' arrow key was already down last frame; PAN_REPEAT counts frames
' until the next auto-step fires so a held key doesn't fly across
' the map.
PAN_HOLD = 0
PAN_REPEAT = 0

BTN_LOAD_X0 = 8   : BTN_LOAD_Y0 = 4 : BTN_LOAD_X1 = 64  : BTN_LOAD_Y1 = 24
BTN_SAVE_X0 = 72  : BTN_SAVE_Y0 = 4 : BTN_SAVE_X1 = 128 : BTN_SAVE_Y1 = 24
BTN_PREV_X0 = 136 : BTN_PREV_Y0 = 4 : BTN_PREV_X1 = 158 : BTN_PREV_Y1 = 24
BTN_FWD_X0 = 162 : BTN_FWD_Y0 = 4 : BTN_FWD_X1 = 184 : BTN_FWD_Y1 = 24
BTN_QUIT_X0 = 592 : BTN_QUIT_Y0 = 4 : BTN_QUIT_X1 = 632 : BTN_QUIT_Y1 = 24

SELECTED = 1
Q$ = CHR$(34)

STATUS$ = "PICK A TILE LEFT, LEFT-DRAG ON MAP TO PAINT, RIGHT ERASES, ARROWS PAN."
STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 220

' Boot: load the first preset (or fall back to a blank 10x10 if
' the file isn't there yet — happens for "map.json" on first run).
LoadCurrentMap()

DrawChrome()

PREV_L = 0
PREV_R = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  HandlePan()

  MX = GETMOUSEX()
  MY = GETMOUSEY()
  L  = ISMOUSEBUTTONDOWN(0)
  R  = ISMOUSEBUTTONDOWN(1)

  ' --- input: edge-triggered clicks (buttons + picker) ---
  IF L = 1 AND PREV_L = 0 THEN
    IF MX >= BTN_QUIT_X0 AND MX <= BTN_QUIT_X1 AND MY >= BTN_QUIT_Y0 AND MY <= BTN_QUIT_Y1 THEN EXIT

    IF MX >= BTN_SAVE_X0 AND MX <= BTN_SAVE_X1 AND MY >= BTN_SAVE_Y0 AND MY <= BTN_SAVE_Y1 THEN
      SaveCurrentMap()
    END IF

    IF MX >= BTN_LOAD_X0 AND MX <= BTN_LOAD_X1 AND MY >= BTN_LOAD_Y0 AND MY <= BTN_LOAD_Y1 THEN
      LoadCurrentMap()
    END IF

    IF MX >= BTN_PREV_X0 AND MX <= BTN_PREV_X1 AND MY >= BTN_PREV_Y0 AND MY <= BTN_PREV_Y1 THEN
      CycleMap(-1)
    END IF
    IF MX >= BTN_FWD_X0 AND MX <= BTN_FWD_X1 AND MY >= BTN_FWD_Y0 AND MY <= BTN_FWD_Y1 THEN
      CycleMap(1)
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
  IF L = 1 AND MX >= MAP_X AND MX < MAP_X + VIEW_COLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + VIEW_ROWS * TILE_SIZE THEN
    CX = (MX - MAP_X) \ TILE_SIZE + CAM_COL
    CY = (MY - MAP_Y) \ TILE_SIZE + CAM_ROW
    IF CX >= 0 AND CX < MCOLS AND CY >= 0 AND CY < MROWS THEN
      IDX = CY * MCOLS + CX
      IF IDX >= 0 AND IDX < MAP_COUNT THEN MAP(IDX) = SELECTED
    END IF
  END IF

  ' --- right-drag erases ---
  IF R = 1 AND MX >= MAP_X AND MX < MAP_X + VIEW_COLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + VIEW_ROWS * TILE_SIZE THEN
    CX = (MX - MAP_X) \ TILE_SIZE + CAM_COL
    CY = (MY - MAP_Y) \ TILE_SIZE + CAM_ROW
    IF CX >= 0 AND CX < MCOLS AND CY >= 0 AND CY < MROWS THEN
      IDX = CY * MCOLS + CX
      IF IDX >= 0 AND IDX < MAP_COUNT THEN MAP(IDX) = 0
    END IF
  END IF

  TILEMAP CLEAR
  DrawHeader()
  DrawPicker()
  DrawMap()
  DrawHighlight()
  DrawStatus()

  PREV_L = L
  PREV_R = R
  VSYNC
LOOP
END

' ------------------------------------------------------------
'  UI helpers
' ------------------------------------------------------------

FUNCTION DrawChrome()
  COLORRGB 56, 56, 80  : FILLRECT 0, 0 TO 639, TOOLBAR_H - 1
  COLORRGB 160, 160, 200 : LINE 0, TOOLBAR_H - 1 TO 639, TOOLBAR_H - 1
  COLORRGB 80, 80, 96
  FILLRECT BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
  FILLRECT BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
  FILLRECT BTN_PREV_X0, BTN_PREV_Y0 TO BTN_PREV_X1, BTN_PREV_Y1
  FILLRECT BTN_FWD_X0, BTN_FWD_Y0 TO BTN_FWD_X1, BTN_FWD_Y1
  FILLRECT BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
  COLORRGB 200, 200, 220
  RECT BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
  RECT BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
  RECT BTN_PREV_X0, BTN_PREV_Y0 TO BTN_PREV_X1, BTN_PREV_Y1
  RECT BTN_FWD_X0, BTN_FWD_Y0 TO BTN_FWD_X1, BTN_FWD_Y1
  RECT BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
  COLORRGB 255, 255, 255
  DRAWTEXT BTN_LOAD_X0 + 8, BTN_LOAD_Y0 + 8, "LOAD"
  DRAWTEXT BTN_SAVE_X0 + 8, BTN_SAVE_Y0 + 8, "SAVE"
  DRAWTEXT BTN_PREV_X0 + 8, BTN_PREV_Y0 + 8, "<"
  DRAWTEXT BTN_FWD_X0 + 8, BTN_FWD_Y0 + 8, ">"
  DRAWTEXT BTN_QUIT_X0 + 4, BTN_QUIT_Y0 + 8, "QUIT"
END FUNCTION

' Header band (path + dimensions) re-stamped each frame so cycle
' button updates show without redrawing the whole toolbar.
FUNCTION DrawHeader()
  COLORRGB 32, 32, 48 : FILLRECT 0, HEADER_BAND_Y TO 639, HEADER_BAND_Y + HEADER_BAND_H - 1
  COLORRGB 220, 220, 220
  DRAWTEXT 200, HEADER_BAND_Y + 4, CURRENT_MAP$
  DIM_TXT$ = STR$(MCOLS) + "x" + STR$(MROWS) + " @ " + STR$(TILE_SIZE) + "px"
  DRAWTEXT 460, HEADER_BAND_Y + 4, DIM_TXT$
  COLORRGB 220, 220, 220
  DRAWTEXT PICKER_X, PICKER_Y - 12, "TILE PICKER"
  DRAWTEXT MAP_X,    MAP_Y    - 12, "MAP"
END FUNCTION

FUNCTION DrawPicker()
  COLORRGB 24, 24, 32
  FILLRECT PICKER_X - 2, PICKER_Y - 2 TO PICKER_X + PCOLS * TILE_SIZE + 1, PICKER_Y + PROWS * TILE_SIZE + 1
  TILEMAP DRAW 0, PICKER_X, PICKER_Y, PCOLS, PROWS, PICKER()
  COLORRGB 80, 80, 100
  FOR PIDX =0 TO PICK_COUNT - 1
    GX = PICKER_X + (PIDX MOD PCOLS) * TILE_SIZE
    GY = PICKER_Y + (PIDX \ PCOLS) * TILE_SIZE
    RECT GX, GY TO GX + TILE_SIZE - 1, GY + TILE_SIZE - 1
  NEXT PIDX
END FUNCTION

' Renders the VIEW_COLS x VIEW_ROWS slice of MAP() starting at
' (CAM_COL, CAM_ROW). VIEW_BUF is reused each frame; TILEMAP DRAW
' iterates VIEW_COLS * VIEW_ROWS cells.
FUNCTION DrawMap()
  COLORRGB 16, 16, 24
  FILLRECT MAP_X - 2, MAP_Y - 2 TO MAP_X + VIEW_COLS * TILE_SIZE + 1, MAP_Y + VIEW_ROWS * TILE_SIZE + 1
  FOR VR = 0 TO VIEW_ROWS - 1
    FOR VC = 0 TO VIEW_COLS - 1
      WC = CAM_COL + VC
      WR = CAM_ROW + VR
      CELL = 0
      IF WC >= 0 AND WC < MCOLS AND WR >= 0 AND WR < MROWS THEN
        CELL = MAP(WR * MCOLS + WC)
      END IF
      VIEW_BUF(VR * VIEW_COLS + VC) = CELL
    NEXT VC
  NEXT VR
  TILEMAP DRAW 0, MAP_X, MAP_Y, VIEW_COLS, VIEW_ROWS, VIEW_BUF()
  COLORRGB 80, 80, 100
  FOR PIDX =0 TO VIEW_COLS * VIEW_ROWS - 1
    GX = MAP_X + (PIDX MOD VIEW_COLS) * TILE_SIZE
    GY = MAP_Y + (PIDX \ VIEW_COLS) * TILE_SIZE
    RECT GX, GY TO GX + TILE_SIZE - 1, GY + TILE_SIZE - 1
  NEXT PIDX
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

' Arrow keys pan the viewport over MCOLS x MROWS in 1-cell steps.
' Edge-triggered via PAN_HOLD so a held key doesn't fly across the
' map; a small repeat-after frames so deliberate scrolling is fast.
FUNCTION HandlePan()
  KU = 0 : KD = 0 : KL = 0 : KR = 0
  IF KEYDOWN(KEY_UP)    THEN KU = 1
  IF KEYDOWN(KEY_DOWN)  THEN KD = 1
  IF KEYDOWN(KEY_LEFT)  THEN KL = 1
  IF KEYDOWN(KEY_RIGHT) THEN KR = 1
  ANY_KEY = KU OR KD OR KL OR KR
  IF ANY_KEY = 0 THEN
    PAN_HOLD = 0
    PAN_REPEAT = 0
    RETURN 0
  END IF
  PAN_STEP = 0
  IF PAN_HOLD = 0 THEN
    PAN_STEP = 1
  ELSE
    PAN_REPEAT = PAN_REPEAT + 1
    IF PAN_REPEAT >= 6 THEN
      PAN_STEP = 1
      PAN_REPEAT = 0
    END IF
  END IF
  PAN_HOLD = 1
  IF PAN_STEP = 1 THEN
    IF KU = 1 THEN CAM_ROW = CAM_ROW - 1
    IF KD = 1 THEN CAM_ROW = CAM_ROW + 1
    IF KL = 1 THEN CAM_COL = CAM_COL - 1
    IF KR = 1 THEN CAM_COL = CAM_COL + 1
    IF CAM_COL < 0 THEN CAM_COL = 0
    IF CAM_ROW < 0 THEN CAM_ROW = 0
    IF CAM_COL > MCOLS - VIEW_COLS THEN CAM_COL = MCOLS - VIEW_COLS
    IF CAM_ROW > MROWS - VIEW_ROWS THEN CAM_ROW = MROWS - VIEW_ROWS
    IF CAM_COL < 0 THEN CAM_COL = 0
    IF CAM_ROW < 0 THEN CAM_ROW = 0
  END IF
END FUNCTION

' ------------------------------------------------------------
'  Map switch + tileset reload
' ------------------------------------------------------------

FUNCTION CycleMap(direction)
  PRESET_IDX = PRESET_IDX + direction
  IF PRESET_IDX < 0 THEN PRESET_IDX = PRESET_COUNT - 1
  IF PRESET_IDX >= PRESET_COUNT THEN PRESET_IDX = 0
  CURRENT_MAP$ = PRESET_PATH$(PRESET_IDX)
  STATUS$ = "READY: " + CURRENT_MAP$ + " (CLICK LOAD)"
  STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 255
END FUNCTION

' Extract the directory portion of a path (everything up to and
' including the last /). Returns "" if path has no slash.
FUNCTION DirOf$(p$)
  PLEN = LEN(p$)
  LAST = -1
  FOR PIDX =1 TO PLEN
    IF MID$(p$, PIDX, 1) = "/" THEN LAST = PIDX
  NEXT PIDX
  IF LAST = -1 THEN RETURN ""
  RETURN LEFT$(p$, LAST)
END FUNCTION

FUNCTION LoadCurrentMap()
  ' Probe for the file first — MAPLOAD raises a runtime error on a
  ' missing path. ST=1 after OPEN signals "not found"; bail with a
  ' friendly status instead. Special-case map.json: if missing, fall
  ' back to a blank 10x10 grid so first-run still works.
  OPEN 1, 1, 0, CURRENT_MAP$
  IF ST = 1 THEN
    IF CURRENT_MAP$ = "map.json" THEN
      ResetBlankMap()
      STATUS$ = "NEW BLANK 10x10 (SAVE TO CREATE map.json)"
      STATUS_R = 200 : STATUS_G = 200 : STATUS_B = 255
    ELSE
      STATUS$ = "FILE NOT FOUND: " + CURRENT_MAP$
      STATUS_R = 255 : STATUS_G = 200 : STATUS_B = 200
    END IF
    RETURN 0
  END IF
  CLOSE #1
  MAPLOAD CURRENT_MAP$
  MCOLS = MAP_W
  MROWS = MAP_H
  TILE_SIZE = MAP_TILE_W
  MAP_COUNT = MCOLS * MROWS
  IF MAP_COUNT > MAP_CAP THEN MAP_COUNT = MAP_CAP
  FOR LI = 0 TO MAP_COUNT - 1
    MAP(LI) = MAP_BG(LI)
  NEXT LI
  ' Tileset path in the JSON is relative to the JSON's directory;
  ' join with DirOf(CURRENT_MAP$) so SPRITE LOAD finds it from CWD.
  TILESET_DIR$ = DirOf$(CURRENT_MAP$)
  TILESET_SRC$ = TILESET_DIR$ + MAP_TILESET_SRC$(0)
  ReloadTileset()
  CAM_COL = 0
  CAM_ROW = 0
  VIEW_COLS = WIN_PX_W \ TILE_SIZE
  VIEW_ROWS = WIN_PX_H \ TILE_SIZE
  IF VIEW_COLS > MCOLS THEN VIEW_COLS = MCOLS
  IF VIEW_ROWS > MROWS THEN VIEW_ROWS = MROWS
  STATUS$ = "LOADED " + CURRENT_MAP$
  STATUS_R = 200 : STATUS_G = 255 : STATUS_B = 200
END FUNCTION

FUNCTION ResetBlankMap()
  MCOLS = 10
  MROWS = 10
  TILE_SIZE = 32
  MAP_COUNT = MCOLS * MROWS
  TILESET_DIR$ = ""
  TILESET_SRC$ = "walls.png"
  FOR RI = 0 TO MAP_COUNT - 1
    MAP(RI) = 0
  NEXT RI
  ReloadTileset()
  CAM_COL = 0
  CAM_ROW = 0
  VIEW_COLS = WIN_PX_W \ TILE_SIZE
  VIEW_ROWS = WIN_PX_H \ TILE_SIZE
  IF VIEW_COLS > MCOLS THEN VIEW_COLS = MCOLS
  IF VIEW_ROWS > MROWS THEN VIEW_ROWS = MROWS
END FUNCTION

' Re-LOAD slot 0 with the current TILESET_SRC$ + tile size, then
' rebuild the picker array to walk 1..PICK_COUNT. SPRITE LOAD on an
' already-loaded slot replaces the texture; the picker only shows
' the first PCOLS*PROWS entries (32 default), enough for the mini
' tilesets we ship.
FUNCTION ReloadTileset()
  SPRITE LOAD 0, TILESET_SRC$, TILE_SIZE, TILE_SIZE
  PICK_COUNT = TILE COUNT(0)
  IF PICK_COUNT < 0 THEN PICK_COUNT = 0
  IF PICK_COUNT > 128 THEN PICK_COUNT = 128
  PROWS_LIMIT = (PICK_COUNT + PCOLS - 1) \ PCOLS
  IF PROWS_LIMIT < 1 THEN PROWS_LIMIT = 1
  IF PROWS_LIMIT > 8 THEN PROWS_LIMIT = 8
  PROWS = PROWS_LIMIT
  FOR RI = 0 TO PCOLS * PROWS - 1
    IF RI < PICK_COUNT THEN
      PICKER(RI) = RI + 1
    ELSE
      PICKER(RI) = 0
    END IF
  NEXT RI
  IF SELECTED > PICK_COUNT THEN SELECTED = 1
  IF SELECTED < 1 THEN SELECTED = 1
END FUNCTION

' ------------------------------------------------------------
'  JSON save — canonical map format v1
' ------------------------------------------------------------

FUNCTION SaveCurrentMap()
  ' Writes a v1 JSON: format/size/tileSize/tilesets/layers[bg].
  ' Object/collision/animation layers from MAPLOAD are NOT preserved
  ' yet — saving an RPG/shooter map here drops its NPCs, doors, and
  ' triggers. That's intentional for the MVP editor (paints tiles
  ' only). Round-trip-safe round-tripping is a TODO.
  TS_SHORT$ = MAP_TILESET_SRC$(0)
  IF TS_SHORT$ = "" THEN TS_SHORT$ = "walls.png"
  TS_ID$ = MAP_TILESET_ID$(0)
  IF TS_ID$ = "" THEN TS_ID$ = "walls"
  OPEN 1, 1, 1, CURRENT_MAP$
  PRINT#1, "{"
  PRINT#1, "  " + Q$ + "format" + Q$ + ": 1,"
  PRINT#1, "  " + Q$ + "id" + Q$ + ": " + Q$ + "editor-map" + Q$ + ","
  PRINT#1, "  " + Q$ + "size" + Q$ + ": { " + Q$ + "cols" + Q$ + ": " + STR$(MCOLS) + ", " + Q$ + "rows" + Q$ + ": " + STR$(MROWS) + " },"
  PRINT#1, "  " + Q$ + "tileSize" + Q$ + ": { " + Q$ + "w" + Q$ + ": " + STR$(TILE_SIZE) + ", " + Q$ + "h" + Q$ + ": " + STR$(TILE_SIZE) + " },"
  PRINT#1, "  " + Q$ + "tilesets" + Q$ + ": ["
  PRINT#1, "    { " + Q$ + "id" + Q$ + ": " + Q$ + TS_ID$ + Q$ + ", " + Q$ + "src" + Q$ + ": " + Q$ + TS_SHORT$ + Q$ + ", " + Q$ + "cellW" + Q$ + ": " + STR$(TILE_SIZE) + ", " + Q$ + "cellH" + Q$ + ": " + STR$(TILE_SIZE) + " }"
  PRINT#1, "  ],"
  PRINT#1, "  " + Q$ + "layers" + Q$ + ": ["
  PRINT#1, "    { " + Q$ + "name" + Q$ + ": " + Q$ + "bg" + Q$ + ", " + Q$ + "type" + Q$ + ": " + Q$ + "tiles" + Q$ + ", " + Q$ + "tilesetId" + Q$ + ": " + Q$ + TS_ID$ + Q$ + ","
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
  STATUS$ = "SAVED " + CURRENT_MAP$
  STATUS_R = 200 : STATUS_G = 255 : STATUS_B = 200
END FUNCTION
