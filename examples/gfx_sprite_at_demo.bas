' ============================================================
'  gfx_sprite_at_demo - SPRITEAT + drag-and-drop with Z order
'
'  SPRITEAT(x, y) returns the topmost visible sprite whose
'  last-drawn rect contains (x, y), or -1. DRAWSPRITE's
'  z argument breaks ties - higher Z wins. Draw order in the
'  cell list is preserved by SCREEN SWAP / VSYNC.
'
'  This demo stacks three sprites so they overlap. Click to
'  pick up whichever is on top under the cursor; drag moves
'  it and bumps it to the front of the Z stack; release drops.
'
'  Keys: Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
DOUBLEBUFFER ON

LOADSPRITE 1, "boing.png"
LOADSPRITE 2, "chick.png"
LOADSPRITE 3, "ship.png"

' Shrink to fit three on screen.
SPRITEMODULATE 1, 255, 255, 255, 255, 0.25, 0.25
SPRITEMODULATE 2, 255, 255, 255, 255, 0.30, 0.30
SPRITEMODULATE 3, 255, 255, 255, 255, 0.30, 0.30

DIM SX(4), SY(4), SZ(4)
SX(1) =  80 : SY(1) =  80 : SZ(1) = 1
SX(2) = 110 : SY(2) = 100 : SZ(2) = 2
SX(3) = 140 : SY(3) =  90 : SZ(3) = 3

DRAGGING = 0
OFFX = 0
OFFY = 0
TOPZ = 3

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  ' Draw all three - Z order drives paint order AND hit-test tie-break.
  FOR I = 1 TO 3
    DRAWSPRITE I, SX(I), SY(I), SZ(I)
  NEXT I

  MX = GETMOUSEX()
  MY = GETMOUSEY()

  ' Begin drag: pick topmost sprite whose opaque pixel is under the
  ' pointer. SPRITEAT gives the Z-ordered bbox candidate; the follow-up
  ' ISMOUSEOVERSPRITE(slot, 16) check rejects transparent PNG corners
  ' so the user can't grab a sprite by its edge halo.
  IF DRAGGING = 0 AND ISMOUSEBUTTONPRESSED(0) THEN
    HIT = SPRITEAT(MX, MY)
    IF HIT >= 1 AND HIT <= 3 THEN
      IF ISMOUSEOVERSPRITE(HIT, 16) THEN
        DRAGGING = HIT
        OFFX = MX - SX(HIT)
        OFFY = MY - SY(HIT)
        TOPZ = TOPZ + 1
        SZ(HIT) = TOPZ
      END IF
    END IF
  END IF

  ' Track.
  IF DRAGGING > 0 AND ISMOUSEBUTTONDOWN(0) THEN
    SX(DRAGGING) = MX - OFFX
    SY(DRAGGING) = MY - OFFY
  END IF

  ' Drop.
  IF DRAGGING > 0 AND ISMOUSEBUTTONRELEASED(0) THEN
    DRAGGING = 0
  END IF

  ' HUD band.
  CLS 0, 170 TO 319, 199
  COLOR 7
  HOV = SPRITEAT(MX, MY)
  IF HOV >= 0 THEN
    DRAWTEXT 8, 176, "HOVER SLOT " + STR$(HOV), 1
  ELSE
    DRAWTEXT 8, 176, "MOVE OVER A SPRITE", 1
  END IF
  IF DRAGGING > 0 THEN
    COLOR 10
    DRAWTEXT 8, 190, "DRAGGING SLOT " + STR$(DRAGGING) + "  Z=" + STR$(SZ(DRAGGING)), 1
  END IF
  COLOR 14
  DRAWTEXT 240, 190, "Q QUIT", 1

  VSYNC
LOOP

UNLOADSPRITE 1
UNLOADSPRITE 2
UNLOADSPRITE 3
