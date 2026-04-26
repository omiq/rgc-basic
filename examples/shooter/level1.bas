' ============================================================
'  shooter/level1.bas — MVP-1 vertical shooter, stage 1
'
'  Pre-baked level data for the maplib.bas convention. Sets all
'  required MAP_* globals and the engine-specific MAP_OBJ_*$/numeric
'  arrays before the main game loop in shooter.bas runs.
'
'  Tileset: walls.png (256x128, 8x4 grid of 32x32 tiles).
'    1..32 = decoration / floor / debris.
'    13, 20 = solid obstacles (block player + projectiles).
'
'  Object list: player spawn at bottom-centre, ~10 enemies sprinkled
'  up the map, one boss trigger at the top.
' ============================================================

MAP_W       = 10
MAP_H       = 100
MAP_TILE_W  = 32
MAP_TILE_H  = 32

DIM MAP_BG(MAP_W * MAP_H - 1)
DIM MAP_FG(MAP_W * MAP_H - 1)

' Floor every cell with tile 1 — gives the bg something visible.
FOR L1I = 0 TO MAP_W * MAP_H - 1
  MAP_BG(L1I) = 6
  MAP_FG(L1I) = 0
NEXT L1I

' Scatter solid obstacles (tile ids 13 and 20). Skip the bottom 4
' rows so the player spawn has clear airspace to start.
FOR L1ROW = 4 TO MAP_H - 4 STEP 5
  L1C = (L1ROW * 7) MOD MAP_W
  MAP_BG(L1ROW * MAP_W + L1C) = 13
  L1C2 = (L1C + 5) MOD MAP_W
  MAP_BG(L1ROW * MAP_W + L1C2) = 20
NEXT L1ROW

' Solid tile id list.
MAP_COLL_COUNT = 2
DIM MAP_COLL(MAP_COLL_COUNT - 1)
MAP_COLL(0) = 13
MAP_COLL(1) = 20

' Object list: index 0 = player spawn, then enemies, then boss trigger.
' KIND: "player" | "ship" | "tank" | "boss"
MAP_OBJ_COUNT = 14
DIM MAP_OBJ_TYPE$(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_KIND$(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_X(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_Y(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_W(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_H(MAP_OBJ_COUNT - 1)
DIM MAP_OBJ_ID(MAP_OBJ_COUNT - 1)

' Player spawn (bottom-centre of map; 32px above world bottom).
MAP_OBJ_TYPE$(0) = "spawn"  : MAP_OBJ_KIND$(0) = "player"
MAP_OBJ_X(0) = 144 : MAP_OBJ_Y(0) = MAP_H * MAP_TILE_H - 64
MAP_OBJ_W(0) = 32  : MAP_OBJ_H(0) = 32 : MAP_OBJ_ID(0) = 1

' Enemies — Y values count up the map (camera starts at bottom and
' scrolls up, so smaller Y = encountered later).
MAP_OBJ_TYPE$(1)  = "enemy" : MAP_OBJ_KIND$(1)  = "ship" : MAP_OBJ_X(1)  =  32 : MAP_OBJ_Y(1)  = 2700 : MAP_OBJ_W(1)  = 32 : MAP_OBJ_H(1)  = 32 : MAP_OBJ_ID(1)  = 2
MAP_OBJ_TYPE$(2)  = "enemy" : MAP_OBJ_KIND$(2)  = "ship" : MAP_OBJ_X(2)  = 256 : MAP_OBJ_Y(2)  = 2500 : MAP_OBJ_W(2)  = 32 : MAP_OBJ_H(2)  = 32 : MAP_OBJ_ID(2)  = 3
MAP_OBJ_TYPE$(3)  = "enemy" : MAP_OBJ_KIND$(3)  = "ship" : MAP_OBJ_X(3)  =  96 : MAP_OBJ_Y(3)  = 2300 : MAP_OBJ_W(3)  = 32 : MAP_OBJ_H(3)  = 32 : MAP_OBJ_ID(3)  = 4
MAP_OBJ_TYPE$(4)  = "enemy" : MAP_OBJ_KIND$(4)  = "tank" : MAP_OBJ_X(4)  = 192 : MAP_OBJ_Y(4)  = 2100 : MAP_OBJ_W(4)  = 32 : MAP_OBJ_H(4)  = 32 : MAP_OBJ_ID(4)  = 5
MAP_OBJ_TYPE$(5)  = "enemy" : MAP_OBJ_KIND$(5)  = "ship" : MAP_OBJ_X(5)  =  32 : MAP_OBJ_Y(5)  = 1900 : MAP_OBJ_W(5)  = 32 : MAP_OBJ_H(5)  = 32 : MAP_OBJ_ID(5)  = 6
MAP_OBJ_TYPE$(6)  = "enemy" : MAP_OBJ_KIND$(6)  = "ship" : MAP_OBJ_X(6)  = 288 : MAP_OBJ_Y(6)  = 1700 : MAP_OBJ_W(6)  = 32 : MAP_OBJ_H(6)  = 32 : MAP_OBJ_ID(6)  = 7
MAP_OBJ_TYPE$(7)  = "enemy" : MAP_OBJ_KIND$(7)  = "ship" : MAP_OBJ_X(7)  = 160 : MAP_OBJ_Y(7)  = 1500 : MAP_OBJ_W(7)  = 32 : MAP_OBJ_H(7)  = 32 : MAP_OBJ_ID(7)  = 8
MAP_OBJ_TYPE$(8)  = "enemy" : MAP_OBJ_KIND$(8)  = "tank" : MAP_OBJ_X(8)  =  64 : MAP_OBJ_Y(8)  = 1300 : MAP_OBJ_W(8)  = 32 : MAP_OBJ_H(8)  = 32 : MAP_OBJ_ID(8)  = 9
MAP_OBJ_TYPE$(9)  = "enemy" : MAP_OBJ_KIND$(9)  = "ship" : MAP_OBJ_X(9)  = 224 : MAP_OBJ_Y(9)  = 1100 : MAP_OBJ_W(9)  = 32 : MAP_OBJ_H(9)  = 32 : MAP_OBJ_ID(9)  = 10
MAP_OBJ_TYPE$(10) = "enemy" : MAP_OBJ_KIND$(10) = "ship" : MAP_OBJ_X(10) = 128 : MAP_OBJ_Y(10) =  900 : MAP_OBJ_W(10) = 32 : MAP_OBJ_H(10) = 32 : MAP_OBJ_ID(10) = 11
MAP_OBJ_TYPE$(11) = "enemy" : MAP_OBJ_KIND$(11) = "ship" : MAP_OBJ_X(11) =  32 : MAP_OBJ_Y(11) =  700 : MAP_OBJ_W(11) = 32 : MAP_OBJ_H(11) = 32 : MAP_OBJ_ID(11) = 12
MAP_OBJ_TYPE$(12) = "enemy" : MAP_OBJ_KIND$(12) = "ship" : MAP_OBJ_X(12) = 288 : MAP_OBJ_Y(12) =  500 : MAP_OBJ_W(12) = 32 : MAP_OBJ_H(12) = 32 : MAP_OBJ_ID(12) = 13

' Boss trigger: a marker the engine notices when the camera nears Y=64.
MAP_OBJ_TYPE$(13) = "trigger" : MAP_OBJ_KIND$(13) = "boss" : MAP_OBJ_X(13) = 0 : MAP_OBJ_Y(13) = 64 : MAP_OBJ_W(13) = 320 : MAP_OBJ_H(13) = 8 : MAP_OBJ_ID(13) = 14

' Camera setup — vertical shooter. Start at the bottom of the world,
' scroll up by 1 px per frame (matches gfx_world_demo pacing).
MAP_CAM_START_X = 0
MAP_CAM_START_Y = MAP_H * MAP_TILE_H - 200
MAP_CAM_SCROLL_DIR$ = "up"
MAP_CAM_SPEED_PX_PER_FRAME = 1
