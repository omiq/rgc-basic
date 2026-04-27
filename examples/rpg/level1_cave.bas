' ============================================================
'  rpg/level1_cave.bas — cave layer (20x12 @ 16x16, single room)
'
'  Defines LoadCave(). rpg.bas swaps the SPRITE LOAD slot 0 to
'  cave.png and calls this when the player steps on a "cave" door.
'
'  Tileset: cave.png (40x25 @ 16x16, 1000 tiles).
'    floor walkable:   2
'    wall solid:       162
'    water solid:      282
'    stairs back:      168   (kind="overworld" door object trigger)
' ============================================================

CAVE_FLOOR  = 1
CAVE_WALL   = 202
CAVE_WATER  = 322
CAVE_STAIRS = 161

FUNCTION LoadCave()
  MAP_W      = 20
  MAP_H      = 12
  MAP_TILE_W = 16
  MAP_TILE_H = 16

  ' Floor every cell with cave floor.
  FOR L2I = 0 TO MAP_W * MAP_H - 1
    MAP_BG(L2I) = CAVE_FLOOR
    MAP_FG(L2I) = 0
  NEXT L2I

  ' Wall border (solid).
  FOR L2C = 0 TO MAP_W - 1
    MAP_BG(0 * MAP_W + L2C) = CAVE_WALL
    MAP_BG((MAP_H - 1) * MAP_W + L2C) = CAVE_WALL
  NEXT L2C
  FOR L2R = 0 TO MAP_H - 1
    MAP_BG(L2R * MAP_W + 0) = CAVE_WALL
    MAP_BG(L2R * MAP_W + (MAP_W - 1)) = CAVE_WALL
  NEXT L2R

  ' Small pond of cave water (solid).
  FOR L2R = 4 TO 6
    FOR L2C = 12 TO 15
      MAP_BG(L2R * MAP_W + L2C) = CAVE_WATER
    NEXT L2C
  NEXT L2R

  ' A small inner wall for cover.
  FOR L2C = 6 TO 9
    MAP_BG(6 * MAP_W + L2C) = CAVE_WALL
  NEXT L2C

  ' Stairs tile sits in the wall at the bottom (visual cue for the
  ' overworld door object). Door trigger is added to the object list
  ' below at cell (10, 10).
  MAP_BG(10 * MAP_W + 10) = CAVE_STAIRS

  MAP_COLL_COUNT = 2
  MAP_COLL(0) = CAVE_WALL
  MAP_COLL(1) = CAVE_WATER

  ' Stairs back to overworld (centre-ish bottom).
  MAP_OBJ_COUNT = 2

  MAP_OBJ_TYPE$(0) = "spawn"
  MAP_OBJ_KIND$(0) = "player"
  MAP_OBJ_X(0) = 10 * 16
  MAP_OBJ_Y(0) = 9 * 16
  MAP_OBJ_W(0) = 16 : MAP_OBJ_H(0) = 32 : MAP_OBJ_ID(0) = 1

  MAP_OBJ_TYPE$(1) = "door"
  MAP_OBJ_KIND$(1) = "overworld"
  MAP_OBJ_X(1) = 10 * 16
  MAP_OBJ_Y(1) = 10 * 16
  MAP_OBJ_W(1) = 16 : MAP_OBJ_H(1) = 16 : MAP_OBJ_ID(1) = 2

  MAP_CAM_START_X = 0
  MAP_CAM_START_Y = 0
  MAP_CAM_SCROLL_DIR$ = "free"
  MAP_CAM_SPEED_PX_PER_FRAME = 0
END FUNCTION
