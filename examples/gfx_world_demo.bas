' ============================================================
'  gfx_world_demo - tilemap world + auto vertical scroll + WASD player
'
'  Combines:
'   TILEMAP DRAW to render a 40x40 world of 32x32 tiles
'   Auto vertical scroll - camera advances every frame at VDIR speed
'                          (W flips scroll up, S flips scroll down)
'   Horizontal push scroll - camera only shifts when the player
'                            reaches a 96px viewport margin
'   KEYDOWN(code) polling so A/D + W/S combine for diagonal motion
'   DRAWSPRITE for the player overlay (ship.png, z = 100)
'
'  Assets: tile_sheet.png (64x32, 2 tiles), ship.png (32x32 alpha)
'  Keys:   A/D move player, W/S flip scroll direction, Q quit
' ============================================================

SPRITE LOAD 0, "tile_sheet.png", 32, 32
SPRITE LOAD 1, "ship.png"

WW = 40 : WH = 40                     ' world grid, tiles
TW = 32 : TH = 32                     ' tile size
VW = 320 : VH = 200                   ' viewport

DIM WORLD(WW * WH - 1)

' Deterministic pattern so the scroll effect is visible
FOR I = 0 TO WW * WH - 1
  IF (I * 17 + 3) - INT((I * 17 + 3) / 9) * 9 = 0 THEN
    WORLD(I) = 2
  ELSE
    WORLD(I) = 1
  END IF
NEXT I

PX = WW * TW / 2  : PY = WH * TH / 2  ' player world-pixel pos
CX = PX - VW / 2  : CY = PY - VH / 2  ' camera (top-left in world)
SPD  = 3                              ' horizontal player speed
VDIR = -1                              ' vertical scroll: +1 down, -1 up
EM   = 96                             ' horizontal edge-push margin

KQ = 81 : KA = 65 : KD = 68 : KW = 87 : KS = 83

DO
  IF KEYDOWN(KQ) THEN EXIT
  IF KEYDOWN(KA) THEN PX = PX - SPD
  IF KEYDOWN(KD) THEN PX = PX + SPD
  IF KEYDOWN(KW) THEN VDIR = -1
  IF KEYDOWN(KS) THEN VDIR = 1

  ' Vertical: auto-advance camera and player together
  CY = CY + VDIR
  PY = PY + VDIR
  IF CY < 0 THEN
    CY = 0
    VDIR = 1
    PY = CY + VH / 2
  END IF
  IF CY > WH * TH - VH THEN
    CY = WH * TH - VH
    VDIR = -1
    PY = CY + VH / 2
  END IF

  ' Horizontal: clamp player, push-scroll the camera at margins
  IF PX < 0 THEN PX = 0
  IF PX > WW * TW - TW THEN PX = WW * TW - TW
  SCRX = PX - CX
  IF SCRX < EM           THEN CX = PX - EM
  IF SCRX > VW - EM - TW THEN CX = PX - (VW - EM - TW)
  IF CX < 0 THEN CX = 0
  IF CX > WW * TW - VW THEN CX = WW * TW - VW

  CLS
  TILEMAP DRAW 0, -CX, -CY, WW, WH, WORLD()
  DRAWSPRITE 1, PX - CX, PY - CY, 100
  VSYNC
LOOP
