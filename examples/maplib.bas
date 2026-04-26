' ============================================================
'  maplib.bas — RGC-BASIC level/map convention + helpers (MVP v0)
'
'  This is the runtime side of docs/map-format.md. v0 doesn't parse
'  JSON yet — levels are authored as .bas files that #INCLUDE this
'  lib, fill the MAP_* globals listed below, then call game code.
'  When the JSON parser ships (v1.1), MapLoadJson(path$) will
'  populate the same globals — game code stays unchanged.
'
'  Required globals each level .bas must populate:
'    MAP_W, MAP_H                  cells
'    MAP_TILE_W, MAP_TILE_H        pixels (usually 32, 32)
'    MAP_BG(MAP_W * MAP_H - 1)     background tile layer; 0 = blank
'    MAP_FG(MAP_W * MAP_H - 1)     foreground tile layer; 0 = blank
'    MAP_COLL_COUNT                how many tile ids are solid
'    MAP_COLL(MAP_COLL_COUNT - 1)  the solid tile ids
'    MAP_OBJ_COUNT                 number of objects in the obj layer
'    MAP_OBJ_TYPE$(N) MAP_OBJ_KIND$(N)
'    MAP_OBJ_X(N) MAP_OBJ_Y(N) MAP_OBJ_W(N) MAP_OBJ_H(N) MAP_OBJ_ID(N)
'    (props are level-engine specific; reuse MAP_OBJ_PROP_*$ if you
'     want, or store in side arrays in the level file)
'    MAP_CAM_START_X, MAP_CAM_START_Y     pixels
'    MAP_CAM_SCROLL_DIR$                  "up"|"down"|"left"|"right"|"free"
'    MAP_CAM_SPEED_PX_PER_FRAME           per-frame scroll @ 60fps
'
'  Coordinate convention: top-left origin, +X right, +Y down.
'  Tile coords are integers (col, row); object coords are pixels.
' ============================================================

' Tile id on the bg layer. 0 if (col,row) outside map.
FUNCTION MapTileBg(col, row)
  IF col < 0 THEN RETURN 0
  IF col >= MAP_W THEN RETURN 0
  IF row < 0 THEN RETURN 0
  IF row >= MAP_H THEN RETURN 0
  RETURN MAP_BG(row * MAP_W + col)
END FUNCTION

' Tile id on the fg layer. 0 if (col,row) outside map.
FUNCTION MapTileFg(col, row)
  IF col < 0 THEN RETURN 0
  IF col >= MAP_W THEN RETURN 0
  IF row < 0 THEN RETURN 0
  IF row >= MAP_H THEN RETURN 0
  RETURN MAP_FG(row * MAP_W + col)
END FUNCTION

' 1 if tileId appears in the solid list, else 0.
FUNCTION MapTileSolid(tileId)
  IF tileId <= 0 THEN RETURN 0
  MTSI = 0
  WHILE MTSI < MAP_COLL_COUNT
    IF MAP_COLL(MTSI) = tileId THEN RETURN 1
    MTSI = MTSI + 1
  WEND
  RETURN 0
END FUNCTION

' Tile id at world pixel (px, py) on the bg layer. 0 if outside map.
FUNCTION MapTileAtPx(px, py)
  RETURN MapTileBg(px \ MAP_TILE_W, py \ MAP_TILE_H)
END FUNCTION

FUNCTION MapTileSolidAtPx(px, py)
  RETURN MapTileSolid(MapTileAtPx(px, py))
END FUNCTION

' AABB-vs-solid-bg-tiles. Returns 1 if any cell the rect overlaps is
' a solid tile; useful for projectile / player collision.
FUNCTION MapRectHitsSolid(rx, ry, rw, rh)
  HC1 = rx \ MAP_TILE_W
  HC2 = (rx + rw - 1) \ MAP_TILE_W
  HR1 = ry \ MAP_TILE_H
  HR2 = (ry + rh - 1) \ MAP_TILE_H
  HR = HR1
  WHILE HR <= HR2
    HC = HC1
    WHILE HC <= HC2
      HTID = MapTileBg(HC, HR)
      HSOL = MapTileSolid(HTID)
      IF HSOL = 1 THEN RETURN 1
      HC = HC + 1
    WEND
    HR = HR + 1
  WEND
  RETURN 0
END FUNCTION

' World pixel size (helpers so callers don't recompute).
FUNCTION MapPixelW()
  RETURN MAP_W * MAP_TILE_W
END FUNCTION

FUNCTION MapPixelH()
  RETURN MAP_H * MAP_TILE_H
END FUNCTION
