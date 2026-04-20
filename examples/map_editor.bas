' ============================================================
'  map_editor - RGC-BASIC port of the QB64 map-editor demo
'
'  Demonstrates SCREEN 4 (640x400 RGBA) for a desktop-style UI:
'  toolbar buttons, tile picker, map grid, mouse paint, plus
'  binary file SAVE / LOAD of the edited map.
'
'  Skips the external c64chars.bin + tiles.bin the QB64 version
'  loaded (neither shipped in the source repo) and uses solid
'  24x24 hue-stepped colour squares for each tile with the tile
'  index stamped on top.
' ============================================================

SCREEN 4
BACKGROUNDRGB 32, 32, 48
CLS

TOOLBAR_H  = 32
TILE_SIZE  = 24
COLS       = 7
ROWS       = 6
TILE_COUNT = COLS * ROWS
PICKER_X   = 8
PICKER_Y   = TOOLBAR_H + 16
MAP_X      = 240
MAP_Y      = TOOLBAR_H + 16

BTN_LOAD_X0 = 8   : BTN_LOAD_Y0 = 4 : BTN_LOAD_X1 = 64  : BTN_LOAD_Y1 = 24
BTN_SAVE_X0 = 72  : BTN_SAVE_Y0 = 4 : BTN_SAVE_X1 = 128 : BTN_SAVE_Y1 = 24
BTN_QUIT_X0 = 592 : BTN_QUIT_Y0 = 4 : BTN_QUIT_X1 = 632 : BTN_QUIT_Y1 = 24

DIM MAP(TILE_COUNT)
DIM TR(TILE_COUNT), TG(TILE_COUNT), TB(TILE_COUNT)
SELECTED = 1

' Pre-compute a tile palette (simple HSV sweep). Tile 41 stays dark
' so a blank cell on the map visually reads as "empty".
FOR I = 0 TO TILE_COUNT - 1
  IF I = TILE_COUNT - 1 THEN
    TR(I) = 24
    TG(I) = 24
    TB(I) = 32
  ELSE
    HUE    = (I * 17) MOD 360
    SECTOR = HUE \ 60
    F      = (HUE - SECTOR * 60) * 255 \ 60
    Q      = 255 - F
    IF SECTOR = 0 THEN TR(I) = 255 : TG(I) = F   : TB(I) = 0
    IF SECTOR = 1 THEN TR(I) = Q   : TG(I) = 255 : TB(I) = 0
    IF SECTOR = 2 THEN TR(I) = 0   : TG(I) = 255 : TB(I) = F
    IF SECTOR = 3 THEN TR(I) = 0   : TG(I) = Q   : TB(I) = 255
    IF SECTOR = 4 THEN TR(I) = F   : TG(I) = 0   : TB(I) = 255
    IF SECTOR = 5 THEN TR(I) = 255 : TG(I) = 0   : TB(I) = Q
  END IF
NEXT I

' Seed map with blank tile.
FOR I = 0 TO TILE_COUNT - 1
  MAP(I) = TILE_COUNT - 1
NEXT I

' Toolbar
COLORRGB 56, 56, 80
FILLRECT 0, 0 TO 639, TOOLBAR_H - 1
COLORRGB 160, 160, 200
LINE     0, TOOLBAR_H - 1 TO 639, TOOLBAR_H - 1

' Buttons
COLORRGB 80, 80, 96
FILLRECT BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
FILLRECT BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
FILLRECT BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
COLORRGB 200, 200, 220
RECT     BTN_LOAD_X0, BTN_LOAD_Y0 TO BTN_LOAD_X1, BTN_LOAD_Y1
RECT     BTN_SAVE_X0, BTN_SAVE_Y0 TO BTN_SAVE_X1, BTN_SAVE_Y1
RECT     BTN_QUIT_X0, BTN_QUIT_Y0 TO BTN_QUIT_X1, BTN_QUIT_Y1
COLORRGB 255, 255, 255
DRAWTEXT BTN_LOAD_X0 + 8, BTN_LOAD_Y0 + 8, "LOAD"
DRAWTEXT BTN_SAVE_X0 + 8, BTN_SAVE_Y0 + 8, "SAVE"
DRAWTEXT BTN_QUIT_X0 + 8, BTN_QUIT_Y0 + 8, "QUIT"

' Labels
COLORRGB 220, 220, 220
DRAWTEXT PICKER_X, PICKER_Y - 12, "TILE PICKER"
DRAWTEXT MAP_X,    MAP_Y    - 12, "MAP"

' Draw picker grid
FOR I = 0 TO TILE_COUNT - 1
  CX = I MOD COLS
  CY = I \ COLS
  PX = PICKER_X + CX * TILE_SIZE
  PY = PICKER_Y + CY * TILE_SIZE
  COLORRGB TR(I), TG(I), TB(I)
  FILLRECT PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
  COLORRGB 0, 0, 0
  RECT     PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
  COLORRGB 255, 255, 255
  DRAWTEXT PX + 4, PY + 8, STR$(I)
NEXT I

' Draw map grid
FOR I = 0 TO TILE_COUNT - 1
  CX = I MOD COLS
  CY = I \ COLS
  PX = MAP_X + CX * TILE_SIZE
  PY = MAP_Y + CY * TILE_SIZE
  T = MAP(I)
  COLORRGB TR(T), TG(T), TB(T)
  FILLRECT PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
  COLORRGB 80, 80, 100
  RECT     PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
NEXT I

' Highlight selected tile
CX = SELECTED MOD COLS
CY = SELECTED \ COLS
HX = PICKER_X + CX * TILE_SIZE
HY = PICKER_Y + CY * TILE_SIZE
COLORRGB 255, 255, 0
RECT HX - 1, HY - 1 TO HX + TILE_SIZE, HY + TILE_SIZE
RECT HX - 2, HY - 2 TO HX + TILE_SIZE + 1, HY + TILE_SIZE + 1

' Status
COLORRGB 200, 200, 220
DRAWTEXT 8, 384, "LEFT CLICK A TILE, THEN LEFT CLICK THE MAP. RIGHT CLICK CLEARS."

' Main loop
PREV_L = 0
PREV_R = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  MX = GETMOUSEX()
  MY = GETMOUSEY()
  L  = ISMOUSEBUTTONDOWN(0)
  R  = ISMOUSEBUTTONDOWN(1)

  IF L = 1 AND PREV_L = 0 THEN
    ' QUIT button
    IF MX >= BTN_QUIT_X0 AND MX <= BTN_QUIT_X1 AND MY >= BTN_QUIT_Y0 AND MY <= BTN_QUIT_Y1 THEN EXIT

    ' SAVE button
    IF MX >= BTN_SAVE_X0 AND MX <= BTN_SAVE_X1 AND MY >= BTN_SAVE_Y0 AND MY <= BTN_SAVE_Y1 THEN
      OPEN 1, 1, 1, "map.bin"
      FOR I = 0 TO TILE_COUNT - 1
        PUTBYTE #1, MAP(I)
      NEXT I
      CLOSE #1
      COLORRGB 32, 32, 48 : FILLRECT 0, 376 TO 639, 399
      COLORRGB 200, 255, 200 : DRAWTEXT 8, 384, "SAVED map.bin"
    END IF

    ' LOAD button
    IF MX >= BTN_LOAD_X0 AND MX <= BTN_LOAD_X1 AND MY >= BTN_LOAD_Y0 AND MY <= BTN_LOAD_Y1 THEN
      OPEN 1, 1, 0, "map.bin"
      FOR I = 0 TO TILE_COUNT - 1
        GETBYTE #1, B
        IF B >= 0 AND B < TILE_COUNT THEN MAP(I) = B ELSE MAP(I) = TILE_COUNT - 1
      NEXT I
      CLOSE #1
      ' Re-draw map grid
      FOR I = 0 TO TILE_COUNT - 1
        CX = I MOD COLS
        CY = I \ COLS
        PX = MAP_X + CX * TILE_SIZE
        PY = MAP_Y + CY * TILE_SIZE
        T = MAP(I)
        COLORRGB TR(T), TG(T), TB(T)
        FILLRECT PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
        COLORRGB 80, 80, 100
        RECT     PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
      NEXT I
      COLORRGB 32, 32, 48 : FILLRECT 0, 376 TO 639, 399
      COLORRGB 200, 200, 255 : DRAWTEXT 8, 384, "LOADED map.bin"
    END IF

    ' Tile picker click
    IF MX >= PICKER_X AND MX < PICKER_X + COLS * TILE_SIZE AND MY >= PICKER_Y AND MY < PICKER_Y + ROWS * TILE_SIZE THEN
      CX = (MX - PICKER_X) \ TILE_SIZE
      CY = (MY - PICKER_Y) \ TILE_SIZE
      NEW_SEL = CY * COLS + CX
      IF NEW_SEL >= 0 AND NEW_SEL < TILE_COUNT THEN
        ' Erase previous highlight by redrawing its cell
        OLDCX = SELECTED MOD COLS
        OLDCY = SELECTED \ COLS
        OX = PICKER_X + OLDCX * TILE_SIZE
        OY = PICKER_Y + OLDCY * TILE_SIZE
        COLORRGB 32, 32, 48
        RECT OX - 2, OY - 2 TO OX + TILE_SIZE + 1, OY + TILE_SIZE + 1
        COLORRGB TR(SELECTED), TG(SELECTED), TB(SELECTED)
        FILLRECT OX, OY TO OX + TILE_SIZE - 1, OY + TILE_SIZE - 1
        COLORRGB 0, 0, 0
        RECT     OX, OY TO OX + TILE_SIZE - 1, OY + TILE_SIZE - 1
        COLORRGB 255, 255, 255
        DRAWTEXT OX + 4, OY + 8, STR$(SELECTED)

        SELECTED = NEW_SEL
        HX = PICKER_X + CX * TILE_SIZE
        HY = PICKER_Y + CY * TILE_SIZE
        COLORRGB 255, 255, 0
        RECT HX - 1, HY - 1 TO HX + TILE_SIZE, HY + TILE_SIZE
        RECT HX - 2, HY - 2 TO HX + TILE_SIZE + 1, HY + TILE_SIZE + 1

        COLORRGB 32, 32, 48 : FILLRECT 0, 376 TO 639, 399
        COLORRGB 200, 200, 220 : DRAWTEXT 8, 384, "SELECTED TILE " + STR$(SELECTED)
      END IF
    END IF

    ' Map cell click → paint
    IF MX >= MAP_X AND MX < MAP_X + COLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + ROWS * TILE_SIZE THEN
      CX = (MX - MAP_X) \ TILE_SIZE
      CY = (MY - MAP_Y) \ TILE_SIZE
      IDX = CY * COLS + CX
      IF IDX >= 0 AND IDX < TILE_COUNT THEN
        MAP(IDX) = SELECTED
        PX = MAP_X + CX * TILE_SIZE
        PY = MAP_Y + CY * TILE_SIZE
        COLORRGB TR(SELECTED), TG(SELECTED), TB(SELECTED)
        FILLRECT PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
        COLORRGB 80, 80, 100
        RECT     PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
      END IF
    END IF
  END IF

  IF R = 1 AND PREV_R = 0 THEN
    IF MX >= MAP_X AND MX < MAP_X + COLS * TILE_SIZE AND MY >= MAP_Y AND MY < MAP_Y + ROWS * TILE_SIZE THEN
      CX = (MX - MAP_X) \ TILE_SIZE
      CY = (MY - MAP_Y) \ TILE_SIZE
      IDX = CY * COLS + CX
      IF IDX >= 0 AND IDX < TILE_COUNT THEN
        MAP(IDX) = TILE_COUNT - 1
        PX = MAP_X + CX * TILE_SIZE
        PY = MAP_Y + CY * TILE_SIZE
        COLORRGB TR(TILE_COUNT - 1), TG(TILE_COUNT - 1), TB(TILE_COUNT - 1)
        FILLRECT PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
        COLORRGB 80, 80, 100
        RECT     PX, PY TO PX + TILE_SIZE - 1, PY + TILE_SIZE - 1
      END IF
    END IF
  END IF

  PREV_L = L
  PREV_R = R
  SLEEP 1
LOOP
