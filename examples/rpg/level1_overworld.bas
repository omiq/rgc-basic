' ============================================================
'  rpg/level1_overworld.bas — overworld layer (32x32 @ 16x16)
'
'  Defines LoadOverworld() which fills the maplib MAP_* globals.
'  rpg.bas swaps between this and LoadCave() when player steps on
'  a kind="door" / kind="stairs" object.
'
'  Tileset: Overworld.png (40x36 @ 16x16, 1440 tiles).
'    Tile ids hand-picked against Overworld_ref.png (numbered overlay).
'
'    base ground (grass):  1
'    path / dirt:          1402
'    sand:                 733
'    water (solid):        17    (one of a 4-tile family 17..20)
'    tree (solid):         563
'    rock (solid):         86
'    door (placeholder):   346   (real door is 2 tiles tall —
'                                  swap for the wider sprite later)
'
'  Object list (placed in cell coords, converted to px below):
'    0 = player spawn  cell (4, 28)
'    1 = door to cave  cell (16, 8)
'    2 = NPC           cell (8, 24)
' ============================================================

GRASS_TILE = 1
TREE_TILE  = 563
DIRT_TILE  = 1402
SAND_TILE  = 733
WATER_TILE = 17
ROCK_TILE  = 208
DOOR_TILE  = 346

FUNCTION LoadOverworld()
  MAP_W      = 32
  MAP_H      = 32
  MAP_TILE_W = 16
  MAP_TILE_H = 16

  ' Floor every cell with grass.
  FOR L1I = 0 TO MAP_W * MAP_H - 1
    MAP_BG(L1I) = GRASS_TILE
    MAP_FG(L1I) = 0
  NEXT L1I

  ' Border of trees around the map (solid).
  FOR L1C = 0 TO MAP_W - 1
    MAP_BG(0 * MAP_W + L1C) = TREE_TILE
    MAP_BG((MAP_H - 1) * MAP_W + L1C) = TREE_TILE
  NEXT L1C
  FOR L1R = 0 TO MAP_H - 1
    MAP_BG(L1R * MAP_W + 0) = TREE_TILE
    MAP_BG(L1R * MAP_W + (MAP_W - 1)) = TREE_TILE
  NEXT L1R

  ' Pond of water in the middle (solid).
  FOR L1R = 14 TO 17
    FOR L1C = 14 TO 19
      MAP_BG(L1R * MAP_W + L1C) = WATER_TILE
    NEXT L1C
  NEXT L1R

  ' Path of dirt from spawn (4,28) up to door (16,8) — rough L shape.
  FOR L1R = 8 TO 28
    MAP_BG(L1R * MAP_W + 4) = DIRT_TILE
  NEXT L1R
  FOR L1C = 4 TO 16
    MAP_BG(8 * MAP_W + L1C) = DIRT_TILE
  NEXT L1C

  ' Sand patch around the door so it stands out visually.
  FOR L1R = 7 TO 9
    FOR L1C = 15 TO 17
      MAP_BG(L1R * MAP_W + L1C) = SAND_TILE
    NEXT L1C
  NEXT L1R

  ' Door tile sits ON the sand patch (overwrite after the sand fill).
  ' Real sprite is 2 cells tall — for MVP we use single-cell placeholder
  ' tile 346 at the door cell; the door object trigger is unchanged.
  MAP_BG(8 * MAP_W + 16) = DOOR_TILE

  ' A few scattered rocks (solid).
  MAP_BG(20 * MAP_W + 10) = ROCK_TILE
  MAP_BG(22 * MAP_W + 22) = ROCK_TILE
  MAP_BG(12 * MAP_W + 26) = ROCK_TILE

  ' Solid tile id list (water + tree + rock).
  MAP_COLL_COUNT = 3
  MAP_COLL(0) = WATER_TILE
  MAP_COLL(1) = TREE_TILE
  MAP_COLL(2) = ROCK_TILE

  ' Object list.
  MAP_OBJ_COUNT = 3

  MAP_OBJ_TYPE$(0) = "spawn"
  MAP_OBJ_KIND$(0) = "player"
  MAP_OBJ_X(0) = 4 * 16
  MAP_OBJ_Y(0) = 28 * 16
  MAP_OBJ_W(0) = 16 : MAP_OBJ_H(0) = 32 : MAP_OBJ_ID(0) = 1

  MAP_OBJ_TYPE$(1) = "door"
  MAP_OBJ_KIND$(1) = "cave"
  MAP_OBJ_X(1) = 16 * 16
  MAP_OBJ_Y(1) = 8 * 16
  MAP_OBJ_W(1) = 16 : MAP_OBJ_H(1) = 16 : MAP_OBJ_ID(1) = 2

  MAP_OBJ_TYPE$(2) = "npc"
  MAP_OBJ_KIND$(2) = "old_man"
  MAP_OBJ_X(2) = 8 * 16
  MAP_OBJ_Y(2) = 24 * 16
  MAP_OBJ_W(2) = 16 : MAP_OBJ_H(2) = 32 : MAP_OBJ_ID(2) = 3

  ' Camera setup — free follow with edge clamp; speed unused for RPG.
  MAP_CAM_START_X = 0
  MAP_CAM_START_Y = 0
  MAP_CAM_SCROLL_DIR$ = "free"
  MAP_CAM_SPEED_PX_PER_FRAME = 0
END FUNCTION
