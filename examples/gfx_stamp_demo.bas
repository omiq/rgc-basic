' ============================================================
'  gfx_stamp_demo - 50 moving particles + WASD player
'
'  SPRITE STAMP is not like DRAWSPRITE. DRAWSPRITE keeps one
'  persistent position per slot; STAMP appends to the per-frame
'  cell list, so N calls with the same slot draw N distinct copies.
'
'  Assets: tile.png (32x32 particle), ship.png (32x32 alpha player)
'  Keys:   WASD move player, Q quit
' ============================================================

SPRITE LOAD 0, "tile.png"
SPRITE LOAD 1, "ship.png"

N = 50
DIM SX(N - 1)
DIM SY(N - 1)
DIM SV(N - 1)

FOR I = 0 TO N - 1
  SX(I) = INT(RND(1) * 320)
  SY(I) = INT(RND(1) * 180)
  SV(I) = 1 + INT(RND(1) * 3)
NEXT I

PLX = 144 : PLY = 84

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYDOWN(ASC("A")) THEN PLX = PLX - 2
  IF KEYDOWN(ASC("D")) THEN PLX = PLX + 2
  IF KEYDOWN(ASC("W")) THEN PLY = PLY - 2
  IF KEYDOWN(ASC("S")) THEN PLY = PLY + 2
  IF PLX < 0   THEN PLX = 0
  IF PLX > 288 THEN PLX = 288
  IF PLY < 0   THEN PLY = 0
  IF PLY > 168 THEN PLY = 168

  CLS

  ' 50 SPRITE STAMPs per frame, all slot 0, all distinct positions
  FOR I = 0 TO N - 1
    SX(I) = SX(I) + SV(I)
    IF SX(I) > 320 THEN
      SX(I) = -32
      SY(I) = INT(RND(1) * 180)
    END IF
    SPRITE STAMP 0, SX(I), SY(I), 0, 10
  NEXT I

  ' Player - persistent position, one instance
  DRAWSPRITE 1, PLX, PLY, 100
  VSYNC
LOOP
