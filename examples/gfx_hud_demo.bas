' ============================================================
'  gfx_hud_demo - RECT + FILLRECT + DRAWTEXT + DRAWSPRITE
'
'  Overlay a HUD on top of a scrolling starfield using only the
'  primitive drawing commands (no sprite sheet for the HUD).
'
'  Keys: A/D move player, Q quit
' ============================================================

SCREEN 1
SPRITE LOAD 1, "ship.png"

PLX = 144 : PLY = 160
SC  = 0
N   = 40

DIM SX(N - 1)
DIM SY(N - 1)
DIM SV(N - 1)

FOR I = 0 TO N - 1
  SX(I) = INT(RND(1) * 320)
  SY(I) = INT(RND(1) * 140)
  SV(I) = 1 + INT(RND(1) * 3)
NEXT I

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYDOWN(ASC("A")) THEN PLX = PLX - 3
  IF KEYDOWN(ASC("D")) THEN PLX = PLX + 3
  IF PLX < 0   THEN PLX = 0
  IF PLX > 288 THEN PLX = 288

  ' Erase star area + HUD interior (FILLRECT with COLOR 0; no CLS flicker)
  COLOR 0
  FILLRECT 0,   0 TO 319, 143
  FILLRECT 1, 145 TO 318, 155

  ' Starfield: 40 PSET dots
  COLOR 1
  FOR I = 0 TO N - 1
    SX(I) = SX(I) + SV(I)
    IF SX(I) > 320 THEN
      SX(I) = 0
      SY(I) = INT(RND(1) * 140)
    END IF
    PSET SX(I), SY(I)
  NEXT I

  ' HUD frame (interior was erased so redraw each tick)
  RECT 0, 144 TO 319, 156
  DRAWTEXT   4, 147, "SCORE "
  DRAWTEXT  56, 147, STR$(SC)
  DRAWTEXT 160, 147, "A/D MOVE  Q QUIT"
  FILLRECT 288, 146 TO 288 + (SC / 60) MOD 32, 154
  DRAWSPRITE 1, PLX, PLY, 100

  SC = SC + 1
  VSYNC
LOOP
