' ============================================================
'  rpg/rpg.bas — MVP-2 Zelda-lite
'
'  Validates docs/map-format.md by walking the same MAP_* convention
'  used by shooter, but with:
'    - 16x16 tiles (vs shooter's 32x32)
'    - 16x32 character sprite
'    - tile-based 4-direction movement with AABB-vs-solid collision
'    - level swap (overworld <-> cave) via "door" objects
'    - HUD strip with hearts + dialogue
'
'  Controls:  W A S D  move
'             SPACE    interact (NPC, door, stairs)
'             Q        quit
'
'  Asset pack: ArMM1998 "Zelda-like Tilesets and Sprites" (OpenGameArt).
'  See manifest.txt + asset-spec.md for sheet inventory and tile-id picks.
' ============================================================

#INCLUDE "../maplib.bas"
#INCLUDE "level1_overworld.bas"
#INCLUDE "level1_cave.bas"

SCREEN 2
DOUBLEBUFFER ON
BACKGROUNDRGB 0, 0, 0
CLS

' Sprite slots:
'   0 = Overworld tileset
'   1 = Player char
'   2 = NPC
'   3 = Cave tileset
SPRITE LOAD 0, "Overworld.png", 16, 16
SPRITE LOAD 1, "character.png", 16, 32
SPRITE LOAD 2, "NPC_test.png",  16, 32
SPRITE LOAD 3, "cave.png",      16, 16

VIEW_W = 320
VIEW_H = 200
HUD_H  = 24
PLAY_H = VIEW_H - HUD_H

' Big enough to hold either map (overworld 32x32 = 1024 cells).
MAX_CELLS = 1024
DIM MAP_BG(MAX_CELLS - 1)
DIM MAP_FG(MAX_CELLS - 1)
DIM MAP_COLL(15)
DIM MAP_OBJ_TYPE$(15)
DIM MAP_OBJ_KIND$(15)
DIM MAP_OBJ_X(15)
DIM MAP_OBJ_Y(15)
DIM MAP_OBJ_W(15)
DIM MAP_OBJ_H(15)
DIM MAP_OBJ_ID(15)

' Tile slot used by RenderTiles(). Swapped on level change.
TILE_SLOT = 0
LEVEL$ = "overworld"

' --- player ---
PX = 64                                    ' updated by SetSpawn after load
PY = 64
PSPD = 2
PFACE$ = "down"
PALIVE = 1
LIVES = 3

' --- camera (top-left of viewport in world px) ---
CAM_X = 0
CAM_Y = 0

' --- viewport tile staging buffer ---
'   Both axes are pixel-smooth. The HUD strip lives on the OVERLAY
'   plane (see RenderHud), so the cell-list tilemap composites BELOW
'   the HUD and partial-row tile leak above the HUD bottom is hidden
'   automatically — no need to snap CAM_Y to a tile boundary.
VIEW_COLS = (VIEW_W \ 16) + 2
VIEW_ROWS = (PLAY_H \ 16) + 2
DIM VIEW_TILES(VIEW_COLS * VIEW_ROWS - 1)

' --- dialogue ---
DIALOG$ = ""
DIALOG_TIMER = 0

' --- key codes ---
KQ = 81 : KW = 87 : KA = 65 : KS = 83 : KD = 68 : KSPACE = 32
' Arrow-key constants from the interpreter (CHR$ numbering): KEY_UP=145,
' KEY_DOWN=17, KEY_LEFT=157, KEY_RIGHT=29. Bound alongside WASD so either
' input scheme works.

PREV_SPACE = 0

LoadOverworld()
SetSpawn()

DO
  IF KEYDOWN(KQ) THEN EXIT
  HandleInput()
  HandleInteract()
  CheckDoor()
  UpdateCamera()
  RenderFrame()
  VSYNC
LOOP
END

' ------------------------------------------------------------
'  Helpers
' ------------------------------------------------------------

FUNCTION SetSpawn()
  FOR SI = 0 TO MAP_OBJ_COUNT - 1
    IF MAP_OBJ_TYPE$(SI) = "spawn" THEN
      PX = MAP_OBJ_X(SI)
      PY = MAP_OBJ_Y(SI)
    END IF
  NEXT SI
END FUNCTION

FUNCTION HandleInput()
  IF PALIVE = 0 THEN RETURN 0
  NX = PX
  NY = PY
  IF KEYDOWN(KA) OR KEYDOWN(KEY_LEFT) THEN
    NX = PX - PSPD
    PFACE$ = "left"
  END IF
  IF KEYDOWN(KD) OR KEYDOWN(KEY_RIGHT) THEN
    NX = PX + PSPD
    PFACE$ = "right"
  END IF
  IF KEYDOWN(KW) OR KEYDOWN(KEY_UP) THEN
    NY = PY - PSPD
    PFACE$ = "up"
  END IF
  IF KEYDOWN(KS) OR KEYDOWN(KEY_DOWN) THEN
    NY = PY + PSPD
    PFACE$ = "down"
  END IF

  ' Try X then Y so player slides along walls.
  IF NX <> PX THEN
    IF MapRectHitsSolid(NX + 2, PY + 18, 12, 12) = 0 THEN
      IF NX >= 0 AND NX + 16 <= MapPixelW() THEN PX = NX
    END IF
  END IF
  IF NY <> PY THEN
    IF MapRectHitsSolid(PX + 2, NY + 18, 12, 12) = 0 THEN
      IF NY >= 0 AND NY + 32 <= MapPixelH() THEN PY = NY
    END IF
  END IF
END FUNCTION

FUNCTION HandleInteract()
  SP = KEYDOWN(KSPACE)
  IF SP = 1 AND PREV_SPACE = 0 THEN
    ' Find the nearest interactable object within 24px.
    BEST = -1
    BDIST = 99999
    FOR II = 0 TO MAP_OBJ_COUNT - 1
      IF MAP_OBJ_TYPE$(II) = "npc" THEN
        DX = (MAP_OBJ_X(II) + 8) - (PX + 8)
        DY = (MAP_OBJ_Y(II) + 16) - (PY + 16)
        D = ABS(DX) + ABS(DY)
        IF D < BDIST AND D < 32 THEN
          BDIST = D
          BEST = II
        END IF
      END IF
    NEXT II
    IF BEST >= 0 THEN
      DIALOG$ = "OLD MAN: TAKE THIS GUIDE TO THE CAVE."
      DIALOG_TIMER = 180
    END IF
  END IF
  PREV_SPACE = SP
  IF DIALOG_TIMER > 0 THEN DIALOG_TIMER = DIALOG_TIMER - 1
  IF DIALOG_TIMER = 0 THEN DIALOG$ = ""
END FUNCTION

FUNCTION CheckDoor()
  ' Walk-into door auto-warps.
  FOR DI = 0 TO MAP_OBJ_COUNT - 1
    IF MAP_OBJ_TYPE$(DI) = "door" THEN
      IF PX + 14 >= MAP_OBJ_X(DI) AND PX + 2 <= MAP_OBJ_X(DI) + MAP_OBJ_W(DI) THEN
        IF PY + 28 >= MAP_OBJ_Y(DI) AND PY + 16 <= MAP_OBJ_Y(DI) + MAP_OBJ_H(DI) THEN
          SwapLevel(MAP_OBJ_KIND$(DI))
          RETURN 0
        END IF
      END IF
    END IF
  NEXT DI
END FUNCTION

FUNCTION SwapLevel(target$)
  IF target$ = "cave" THEN
    LEVEL$ = "cave"
    TILE_SLOT = 3
    LoadCave()
    SetSpawn()
  ELSE
    LEVEL$ = "overworld"
    TILE_SLOT = 0
    LoadOverworld()
    ' Spawn next to overworld door instead of default spawn.
    PX = 16 * 16
    PY = 9 * 16
  END IF
END FUNCTION

FUNCTION UpdateCamera()
  TX = PX - VIEW_W \ 2
  TY = PY - PLAY_H \ 2
  WMAX_X = MapPixelW() - VIEW_W
  WMAX_Y = MapPixelH() - PLAY_H
  IF WMAX_X < 0 THEN WMAX_X = 0
  IF WMAX_Y < 0 THEN WMAX_Y = 0
  IF TX < 0 THEN TX = 0
  IF TY < 0 THEN TY = 0
  IF TX > WMAX_X THEN TX = WMAX_X
  IF TY > WMAX_Y THEN TY = WMAX_Y
  CAM_X = TX
  CAM_Y = TY
END FUNCTION

FUNCTION RenderFrame()
  CLS
  RenderTiles()
  RenderObjects()
  RenderPlayer()
  RenderHud()
END FUNCTION

FUNCTION RenderTiles()
  COL0 = CAM_X \ MAP_TILE_W
  ROW0 = CAM_Y \ MAP_TILE_H
  OFF_X = -(CAM_X - COL0 * MAP_TILE_W)
  OFF_Y = -(CAM_Y - ROW0 * MAP_TILE_H) + HUD_H
  FOR VR = 0 TO VIEW_ROWS - 1
    WR = ROW0 + VR
    FOR VC = 0 TO VIEW_COLS - 1
      WC = COL0 + VC
      IF WR >= 0 AND WR < MAP_H AND WC >= 0 AND WC < MAP_W THEN
        VIEW_TILES(VR * VIEW_COLS + VC) = MAP_BG(WR * MAP_W + WC)
      ELSE
        VIEW_TILES(VR * VIEW_COLS + VC) = 0
      END IF
    NEXT VC
  NEXT VR
  TILEMAP DRAW TILE_SLOT, OFF_X, OFF_Y, VIEW_COLS, VIEW_ROWS, VIEW_TILES()
END FUNCTION

FUNCTION RenderObjects()
  FOR OI = 0 TO MAP_OBJ_COUNT - 1
    IF MAP_OBJ_TYPE$(OI) = "npc" THEN
      OSX = MAP_OBJ_X(OI) - CAM_X
      OSY = MAP_OBJ_Y(OI) - CAM_Y + HUD_H
      IF OSX > -16 AND OSX < VIEW_W AND OSY > -32 AND OSY < VIEW_H THEN
        SPRITE STAMP 2, OSX, OSY, 1, 10
      END IF
    END IF
  NEXT OI
END FUNCTION

FUNCTION RenderPlayer()
  IF PALIVE = 1 THEN
    PSX = PX - CAM_X
    PSY = PY - CAM_Y + HUD_H
    PFRAME = 1
    IF PFACE$ = "left"  THEN PFRAME = 52
    IF PFACE$ = "up"    THEN PFRAME = 35
    IF PFACE$ = "right" THEN PFRAME = 18
    SPRITE STAMP 1, PSX, PSY, PFRAME, 20
  END IF
END FUNCTION

FUNCTION RenderHud()
  ' HUD lives on the overlay plane so it always sits ABOVE the
  ' tile cells (Zelda-SNES style top layer). Without this, partial
  ' top tile rows from pixel-smooth Y scroll would composite over
  ' the dialog text. CLS-on-overlay clears just the overlay; world
  ' rendering above is untouched.
  OVERLAY ON
  CLS
  COLORRGB 16, 16, 16
  FILLRECT 0, 0 TO VIEW_W - 1, HUD_H - 1
  COLORRGB 255, 255, 255
  HUD_LBL$ = LEVEL$
  DRAWTEXT 4, 4, "LIFE " + STR$(LIVES) + "  AREA " + HUD_LBL$
  IF DIALOG$ <> "" THEN
    ' Dialog box, SNES-style: dark frame near top of play area, yellow
    ' text on top. Drawn on the overlay so the box never gets clipped
    ' by world tiles even if the camera is mid-scroll.
    COLORRGB 0, 0, 0
    FILLRECT 8, HUD_H + 4 TO VIEW_W - 9, HUD_H + 28
    COLORRGB 255, 255, 255
    FILLRECT 9, HUD_H + 5 TO VIEW_W - 10, HUD_H + 5
    FILLRECT 9, HUD_H + 27 TO VIEW_W - 10, HUD_H + 27
    FILLRECT 9, HUD_H + 5 TO 9, HUD_H + 27
    FILLRECT VIEW_W - 10, HUD_H + 5 TO VIEW_W - 10, HUD_H + 27
    COLORRGB 255, 240, 80
    DRAWTEXT 14, HUD_H + 12, DIALOG$
  END IF
  OVERLAY OFF
END FUNCTION
