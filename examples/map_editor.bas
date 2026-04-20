' ============================================================
'  map_editor - RGC-BASIC port of the QB64 map-editor demo
'
'  Demonstrates the new SCREEN 4 desktop canvas plus the stuff
'  the original relied on:
'    - button-style toolbar rectangles
'    - tile picker grid + map grid
'    - mouse paint (left = selected tile, right = clear)
'    - binary file I/O (SAVE writes map.bin, LOAD reads it back)
'
'  The original QB64 version loaded c64chars.bin + tiles.bin and
'  rasterised 3x3-char tile glyphs pixel-by-pixel via PSET. To
'  keep this demo self-contained we skip the external charset and
'  use solid 24x24 colour squares with the tile index drawn on top
'  via DRAWTEXT — same interaction, no missing-file surprises.
'
'  Layout (640x400):
'     0..32   toolbar (Load / Save / Quit buttons)
'     8..176  tile picker: 7 cols x 6 rows, 24x24 cells
'   240..408  map grid:    7 cols x 6 rows, 24x24 cells
'   left column below tiles: selected-tile preview + status
'
'  LOAD / SAVE read / write "map.bin" in MEMFS. The IDE ships an
'  initial map.bin; your edits persist for the session.
' ============================================================

SCREEN 4
BACKGROUNDRGB 32, 32, 48
CLS

' ---------- layout constants ----------
TOOLBAR_H  = 32
TILE_SIZE  = 24
COLS       = 7
ROWS       = 6
TILE_COUNT = COLS * ROWS
PICKER_X   = 8
PICKER_Y   = TOOLBAR_H + 8
MAP_X      = 240
MAP_Y      = TOOLBAR_H + 8

' Button hit boxes — [x0, y0, x1, y1]
BTN_LOAD_X0 = 8  : BTN_LOAD_Y0 = 4  : BTN_LOAD_X1 = 64  : BTN_LOAD_Y1 = 24
BTN_SAVE_X0 = 72 : BTN_SAVE_Y0 = 4  : BTN_SAVE_X1 = 128 : BTN_SAVE_Y1 = 24
BTN_QUIT_X0 = 592: BTN_QUIT_Y0 = 4  : BTN_QUIT_X1 = 632 : BTN_QUIT_Y1 = 24

' ---------- state ----------
DIM MAP(TILE_COUNT)
SELECTED = 1

' ---------- helpers ----------
FUNCTION draw_button(label$, x0, y0, x1, y1)
  COLORRGB 80, 80, 96
  FILLRECT x0, y0 TO x1, y1
  COLORRGB 200, 200, 220
  RECT     x0, y0 TO x1, y1
  COLORRGB 255, 255, 255
  DRAWTEXT x0 + 6, y0 + 6, label$
  RETURN 0
END FUNCTION

' Pick an RGB triple for a tile index. Simple HSV-ish spread so
' each tile is visually distinct; tile 41 is reserved as "blank".
FUNCTION tile_color(idx)
  IF idx = 41 THEN
    COLORRGB 16, 16, 24
  ELSE
    HUE = (idx * 17) MOD 360
    SECTOR = HUE \ 60
    F = (HUE - SECTOR * 60) * 255 / 60
    Q = 255 - F
    IF SECTOR = 0 THEN COLORRGB 255, F, 0
    IF SECTOR = 1 THEN COLORRGB Q, 255, 0
    IF SECTOR = 2 THEN COLORRGB 0, 255, F
    IF SECTOR = 3 THEN COLORRGB 0, Q, 255
    IF SECTOR = 4 THEN COLORRGB F, 0, 255
    IF SECTOR = 5 THEN COLORRGB 255, 0, Q
  END IF
  RETURN 0
END FUNCTION

FUNCTION draw_tile_cell(idx, px, py)
  TC = tile_color(idx)
  FILLRECT px, py TO px + TILE_SIZE - 1, py + TILE_SIZE - 1
  COLORRGB 0, 0, 0
  RECT     px, py TO px + TILE_SIZE - 1, py + TILE_SIZE - 1
  COLORRGB 255, 255, 255
  LBL$ = STR$(idx)
  DRAWTEXT px + 4, py + 8, LBL$
  RETURN 0
END FUNCTION

FUNCTION draw_picker()
  FOR II = 0 TO TILE_COUNT - 1
    CX = II MOD COLS
    CY = II \ COLS
    PX = PICKER_X + CX * TILE_SIZE
    PY = PICKER_Y + CY * TILE_SIZE
    RC = draw_tile_cell(II, PX, PY)
  NEXT II
  RETURN 0
END FUNCTION

FUNCTION draw_map()
  FOR II = 0 TO TILE_COUNT - 1
    CX = II MOD COLS
    CY = II \ COLS
    PX = MAP_X + CX * TILE_SIZE
    PY = MAP_Y + CY * TILE_SIZE
    RC = draw_tile_cell(MAP(II), PX, PY)
  NEXT II
  RETURN 0
END FUNCTION

FUNCTION highlight_selected()
  CX = SELECTED MOD COLS
  CY = SELECTED \ COLS
  HX = PICKER_X + CX * TILE_SIZE
  HY = PICKER_Y + CY * TILE_SIZE
  COLORRGB 255, 255, 0
  RECT HX - 1, HY - 1 TO HX + TILE_SIZE, HY + TILE_SIZE
  RECT HX - 2, HY - 2 TO HX + TILE_SIZE + 1, HY + TILE_SIZE + 1
  RETURN 0
END FUNCTION

FUNCTION draw_status(msg$)
  COLORRGB 32, 32, 48
  FILLRECT 0, 376 TO 639, 399
  COLORRGB 200, 200, 220
  DRAWTEXT 8, 384, msg$
  RETURN 0
END FUNCTION

FUNCTION save_map()
  OPEN 1, 1, 1, "map.bin"
  FOR II = 0 TO TILE_COUNT - 1
    PUTBYTE #1, MAP(II)
  NEXT II
  CLOSE #1
  RC = draw_status("SAVED map.bin (" + STR$(TILE_COUNT) + " bytes)")
  RETURN 0
END FUNCTION

FUNCTION load_map()
  OPEN 1, 1, 0, "map.bin"
  FOR II = 0 TO TILE_COUNT - 1
    GETBYTE #1, B
    IF B >= 0 AND B < TILE_COUNT THEN MAP(II) = B ELSE MAP(II) = 41
  NEXT II
  CLOSE #1
  RC = draw_map()
  RC = draw_status("LOADED map.bin")
  RETURN 0
END FUNCTION

FUNCTION point_in(px, py, x0, y0, x1, y1)
  IF px >= x0 AND px <= x1 AND py >= y0 AND py <= y1 THEN
    RETURN 1
  END IF
  RETURN 0
END FUNCTION

' ---------- initial frame ----------
' Seed the map with tile 41 (blank) so SAVE has something to write
' before the user paints anything.
FOR II = 0 TO TILE_COUNT - 1
  MAP(II) = 41
NEXT II

' toolbar bg
COLORRGB 56, 56, 80
FILLRECT 0, 0 TO 639, TOOLBAR_H - 1
COLORRGB 160, 160, 200
LINE     0, TOOLBAR_H - 1 TO 639, TOOLBAR_H - 1

RC = draw_button("LOAD",  BTN_LOAD_X0, BTN_LOAD_Y0, BTN_LOAD_X1, BTN_LOAD_Y1)
RC = draw_button("SAVE",  BTN_SAVE_X0, BTN_SAVE_Y0, BTN_SAVE_X1, BTN_SAVE_Y1)
RC = draw_button("QUIT",  BTN_QUIT_X0, BTN_QUIT_Y0, BTN_QUIT_X1, BTN_QUIT_Y1)

' labels
COLORRGB 220, 220, 220
DRAWTEXT PICKER_X, PICKER_Y - 12,  "TILE PICKER"
DRAWTEXT MAP_X,    MAP_Y    - 12,  "MAP"

RC = draw_picker()
RC = draw_map()
RC = highlight_selected()
RC = draw_status("LEFT CLICK A TILE, THEN LEFT CLICK THE MAP. RIGHT CLICK CLEARS.")

' ---------- main loop ----------
PREV_L = 0
PREV_R = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  MX = GETMOUSEX()
  MY = GETMOUSEY()
  L  = ISMOUSEBUTTONDOWN(0)
  R  = ISMOUSEBUTTONDOWN(1)

  ' Edge-trigger on clicks so hold-to-drag doesn't re-fire every
  ' frame; users drag-paint by clicking each cell.
  IF L = 1 AND PREV_L = 0 THEN
    IF point_in(MX, MY, BTN_QUIT_X0, BTN_QUIT_Y0, BTN_QUIT_X1, BTN_QUIT_Y1) THEN EXIT
    IF point_in(MX, MY, BTN_LOAD_X0, BTN_LOAD_Y0, BTN_LOAD_X1, BTN_LOAD_Y1) THEN RC = load_map()
    IF point_in(MX, MY, BTN_SAVE_X0, BTN_SAVE_Y0, BTN_SAVE_X1, BTN_SAVE_Y1) THEN RC = save_map()

    ' Tile picker click
    IF point_in(MX, MY, PICKER_X, PICKER_Y, PICKER_X + COLS * TILE_SIZE - 1, PICKER_Y + ROWS * TILE_SIZE - 1) THEN
      CX = (MX - PICKER_X) \ TILE_SIZE
      CY = (MY - PICKER_Y) \ TILE_SIZE
      NEW_SEL = CY * COLS + CX
      IF NEW_SEL >= 0 AND NEW_SEL < TILE_COUNT THEN
        RC = draw_picker()
        SELECTED = NEW_SEL
        RC = highlight_selected()
        RC = draw_status("SELECTED TILE " + STR$(SELECTED))
      END IF
    END IF

    ' Map cell click → paint with selected
    IF point_in(MX, MY, MAP_X, MAP_Y, MAP_X + COLS * TILE_SIZE - 1, MAP_Y + ROWS * TILE_SIZE - 1) THEN
      CX = (MX - MAP_X) \ TILE_SIZE
      CY = (MY - MAP_Y) \ TILE_SIZE
      IDX = CY * COLS + CX
      IF IDX >= 0 AND IDX < TILE_COUNT THEN
        MAP(IDX) = SELECTED
        PX = MAP_X + CX * TILE_SIZE
        PY = MAP_Y + CY * TILE_SIZE
        RC = draw_tile_cell(SELECTED, PX, PY)
      END IF
    END IF
  END IF

  IF R = 1 AND PREV_R = 0 THEN
    IF point_in(MX, MY, MAP_X, MAP_Y, MAP_X + COLS * TILE_SIZE - 1, MAP_Y + ROWS * TILE_SIZE - 1) THEN
      CX = (MX - MAP_X) \ TILE_SIZE
      CY = (MY - MAP_Y) \ TILE_SIZE
      IDX = CY * COLS + CX
      IF IDX >= 0 AND IDX < TILE_COUNT THEN
        MAP(IDX) = 41
        PX = MAP_X + CX * TILE_SIZE
        PY = MAP_Y + CY * TILE_SIZE
        RC = draw_tile_cell(41, PX, PY)
      END IF
    END IF
  END IF

  PREV_L = L
  PREV_R = R
  SLEEP 1
LOOP

COLORRGB 255, 255, 255
DRAWTEXT 8, 384, "BYE"
