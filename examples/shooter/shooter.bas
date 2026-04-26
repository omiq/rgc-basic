' ============================================================
'  shooter/shooter.bas — MVP-1 vertical shooter
'
'  Validates docs/map-format.md by playing through level1.bas:
'   - 10x100 cell world with 32x32 tiles
'   - tile flag for solid obstacles (tiles 13, 20)
'   - object layer with player spawn + enemies + boss trigger
'   - auto vertical scroll (camera Y decreases each frame)
'
'  Controls:  A / D    move
'             SPACE    fire
'             Q        quit
'
'  Requires basic.c with the udf_returned reset fix in invoke_udf
'  (see tests/function_nested_call_value.bas) — earlier builds
'  failed with a spurious "Missing THEN" when a nested UDF returned
'  inside a WHILE loop.
' ============================================================

#INCLUDE "../maplib.bas"
#INCLUDE "level1.bas"

SCREEN 2
DOUBLEBUFFER ON
BACKGROUNDRGB 0, 0, 0
CLS

SPRITE LOAD 0, "walls.png",         32, 32
SPRITE LOAD 1, "player.png"
SPRITE LOAD 2, "enemy-sprites.png", 32, 32
SPRITE LOAD 3, "tank.png"
SPRITE LOAD 4, "missiles.png",      16, 32

' --- viewport / camera ---
VIEW_W = 320
VIEW_H = 200
VIEW_ROWS = 8                              ' rows in viewport array (covers 200/32 + margin)

CAM_X = 0
CAM_Y = MapPixelH() - VIEW_H               ' bottom of world in view to start

' --- player ---
PX = MAP_OBJ_X(0)                          ' x from level player-spawn (in screen coords; map is 320 wide)
PY = 168                                   ' fixed near bottom of screen
PSPD = 3
PALIVE = 1

' --- player bullets (pool of 16) ---
PB_MAX = 16
DIM PB_X(PB_MAX - 1)
DIM PB_Y(PB_MAX - 1)
DIM PB_ACTIVE(PB_MAX - 1)
PB_SPEED = 6

' --- active enemies (pool of 32) ---
EN_MAX = 32
DIM EN_X(EN_MAX - 1)                       ' world coords
DIM EN_Y(EN_MAX - 1)                       ' world coords
DIM EN_KIND$(EN_MAX - 1)
DIM EN_HP(EN_MAX - 1)
DIM EN_FRAME(EN_MAX - 1)                   ' 1-based sprite frame
DIM EN_ACTIVE(EN_MAX - 1)

' Track which level objects already turned into active enemies so we
' don't double-spawn the same level entry every frame it's in view.
DIM SPAWNED(MAP_OBJ_COUNT - 1)

' --- viewport tile array — rebuilt every frame from MAP_BG ---
DIM VIEW_TILES(MAP_W * VIEW_ROWS - 1)

' --- scoring / state ---
SCORE = 0
LIVES = 3
GAME_OVER = 0
WIN = 0

' --- key codes ---
KQ = 81 : KA = 65 : KD = 68 : KSPACE = 32

' Edge-trigger SPACE so one tap = one bullet.
PREV_FIRE = 0

DO
  IF KEYDOWN(KQ) THEN EXIT

  ' --- input ---
  IF PALIVE = 1 AND GAME_OVER = 0 THEN
    IF KEYDOWN(KA) THEN PX = PX - PSPD
    IF KEYDOWN(KD) THEN PX = PX + PSPD
    IF PX < 0 THEN PX = 0
    IF PX > VIEW_W - 32 THEN PX = VIEW_W - 32

    FIRE = KEYDOWN(KSPACE)
    IF FIRE = 1 AND PREV_FIRE = 0 THEN
      ' Find a free bullet slot. Sentinel instead of GOTO because
      ' rgc-basic's GOTO doesn't unwind FOR/IF nesting and would
      ' leak if_depth across frames.
      PB_DONE = 0
      FOR PBI = 0 TO PB_MAX - 1
        IF PB_ACTIVE(PBI) = 0 AND PB_DONE = 0 THEN
          PB_X(PBI) = PX + 12
          PB_Y(PBI) = PY - 16
          PB_ACTIVE(PBI) = 1
          PB_DONE = 1
        END IF
      NEXT PBI
    END IF
    PREV_FIRE = FIRE
  END IF

  ' --- bullets ---
  FOR PBI = 0 TO PB_MAX - 1
    IF PB_ACTIVE(PBI) = 1 THEN
      PB_Y(PBI) = PB_Y(PBI) - PB_SPEED
      IF PB_Y(PBI) < -16 THEN PB_ACTIVE(PBI) = 0
    END IF
  NEXT PBI

  ' --- camera scroll up (toward Y=0). Stop at top. ---
  IF GAME_OVER = 0 AND WIN = 0 THEN
    IF CAM_Y > 0 THEN
      CAM_Y = CAM_Y - MAP_CAM_SPEED_PX_PER_FRAME
      IF CAM_Y < 0 THEN CAM_Y = 0
    ELSE
      WIN = 1
    END IF
  END IF

  ' --- spawn enemies entering view ---
  FOR OI = 1 TO MAP_OBJ_COUNT - 1
    SP_TRIG = 0
    IF SPAWNED(OI) = 0 AND MAP_OBJ_TYPE$(OI) = "enemy" THEN
      IF MAP_OBJ_Y(OI) >= CAM_Y - 32 AND MAP_OBJ_Y(OI) <= CAM_Y + VIEW_H THEN
        SP_TRIG = 1
      END IF
    END IF
    IF SP_TRIG = 1 THEN
      EN_DONE = 0
      FOR EJ = 0 TO EN_MAX - 1
        IF EN_ACTIVE(EJ) = 0 AND EN_DONE = 0 THEN
          EN_X(EJ) = MAP_OBJ_X(OI)
          EN_Y(EJ) = MAP_OBJ_Y(OI)
          EN_KIND$(EJ) = MAP_OBJ_KIND$(OI)
          EN_HP(EJ) = 1
          EN_FRAME(EJ) = 1
          EN_ACTIVE(EJ) = 1
          SPAWNED(OI) = 1
          EN_DONE = 1
        END IF
      NEXT EJ
    END IF
  NEXT OI

  ' --- update enemies (despawn off bottom of view) ---
  FOR EI = 0 TO EN_MAX - 1
    IF EN_ACTIVE(EI) = 1 THEN
      IF EN_Y(EI) > CAM_Y + VIEW_H + 32 THEN EN_ACTIVE(EI) = 0
    END IF
  NEXT EI

  ' --- bullet vs enemy collision ---
  FOR PBI = 0 TO PB_MAX - 1
    IF PB_ACTIVE(PBI) = 1 THEN
      BX = PB_X(PBI)
      BY = PB_Y(PBI)
      HIT_DONE = 0
      FOR EI = 0 TO EN_MAX - 1
        IF EN_ACTIVE(EI) = 1 AND HIT_DONE = 0 THEN
          ESX = EN_X(EI)
          ESY = EN_Y(EI) - CAM_Y
          IF BX + 8 >= ESX AND BX <= ESX + 32 AND BY + 16 >= ESY AND BY <= ESY + 32 THEN
            EN_HP(EI) = EN_HP(EI) - 1
            PB_ACTIVE(PBI) = 0
            IF EN_HP(EI) <= 0 THEN
              EN_ACTIVE(EI) = 0
              SCORE = SCORE + 100
            END IF
            HIT_DONE = 1
          END IF
        END IF
      NEXT EI
    END IF
  NEXT PBI

  ' --- player vs enemy collision ---
  IF PALIVE = 1 THEN
    P_HIT_DONE = 0
    FOR EI = 0 TO EN_MAX - 1
      IF EN_ACTIVE(EI) = 1 AND P_HIT_DONE = 0 THEN
        ESX = EN_X(EI)
        ESY = EN_Y(EI) - CAM_Y
        IF PX + 32 >= ESX AND PX <= ESX + 32 AND PY + 32 >= ESY AND PY <= ESY + 32 THEN
          EN_ACTIVE(EI) = 0
          LIVES = LIVES - 1
          IF LIVES <= 0 THEN
            PALIVE = 0
            GAME_OVER = 1
          END IF
          P_HIT_DONE = 1
        END IF
      END IF
    NEXT EI
  END IF

  ' --- player vs solid bg tile ---
  IF PALIVE = 1 THEN
    PWX = PX
    PWY = PY + CAM_Y
    IF MapRectHitsSolid(PWX + 4, PWY + 4, 24, 24) = 1 THEN
      LIVES = LIVES - 1
      IF LIVES <= 0 THEN
        PALIVE = 0
        GAME_OVER = 1
      END IF
    END IF
  END IF

  ' --- bullet vs solid bg tile ---
  FOR PBI = 0 TO PB_MAX - 1
    IF PB_ACTIVE(PBI) = 1 THEN
      BWX = PB_X(PBI)
      BWY = PB_Y(PBI) + CAM_Y
      IF MapRectHitsSolid(BWX, BWY, 8, 16) = 1 THEN
        PB_ACTIVE(PBI) = 0
      END IF
    END IF
  NEXT PBI

  ' --- render ---
  CLS

  ' Build the visible-rows tile slice from MAP_BG.
  ROW0 = CAM_Y \ MAP_TILE_H
  OFF_Y = -(CAM_Y - ROW0 * MAP_TILE_H)
  FOR VR = 0 TO VIEW_ROWS - 1
    WR = ROW0 + VR
    FOR VC = 0 TO MAP_W - 1
      IF WR >= 0 AND WR < MAP_H THEN
        VIEW_TILES(VR * MAP_W + VC) = MAP_BG(WR * MAP_W + VC)
      ELSE
        VIEW_TILES(VR * MAP_W + VC) = 0
      END IF
    NEXT VC
  NEXT VR
  TILEMAP DRAW 0, 0, OFF_Y, MAP_W, VIEW_ROWS, VIEW_TILES()

  ' Enemies (z=10).
  FOR EI = 0 TO EN_MAX - 1
    IF EN_ACTIVE(EI) = 1 THEN
      ESX = EN_X(EI)
      ESY = EN_Y(EI) - CAM_Y
      IF EN_KIND$(EI) = "tank" THEN
        SPRITE STAMP 3, ESX, ESY, 1, 10
      ELSE
        SPRITE STAMP 2, ESX, ESY, EN_FRAME(EI), 10
      END IF
    END IF
  NEXT EI

  ' Player bullets (z=12).
  FOR PBI = 0 TO PB_MAX - 1
    IF PB_ACTIVE(PBI) = 1 THEN
      SPRITE STAMP 4, PB_X(PBI), PB_Y(PBI), 1, 12
    END IF
  NEXT PBI

  ' Player (z=20).
  IF PALIVE = 1 THEN
    SPRITE STAMP 1, PX, PY, 1, 20
  END IF

  ' Score / state text — bitmap-plane, drawn before tiles each frame.
  ' (Will be painted under tiles; acceptable for MVP.)
  COLORRGB 255, 255, 255
  DRAWTEXT 4, 4, "SCORE " + STR$(SCORE) + "  LIVES " + STR$(LIVES)
  IF GAME_OVER = 1 THEN
    COLORRGB 255, 80, 80
    DRAWTEXT 110, 90, "GAME OVER"
  END IF
  IF WIN = 1 THEN
    COLORRGB 80, 255, 80
    DRAWTEXT 130, 90, "STAGE CLEAR"
  END IF

  VSYNC
LOOP
END
