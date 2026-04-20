' ============================================================
'  gfx_rotate_demo - SPRITE STAMP with rotation
'
'  The optional 6th arg to SPRITE STAMP is the rotation in degrees:
'    SPRITE STAMP slot, x, y, frame, z, rot_deg
'
'  Rotation pivots around the sprite centre. Only basic-gfx (raylib
'  backend) actually rotates; canvas / WASM accepts the arg but ignores it.
'
'  Sixteen ships fan out in a circle, each pointing outward, and the
'  whole ring spins clockwise over time.
'
'  Keys: Q quit
' ============================================================

SPRITE LOAD 0, "ship.png"
ANTIALIAS ON                ' bilinear sprite filter — smooths rotated edges

CX = 160 : CY = 100
R  = 70
N  = 16
T  = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS
  FOR I = 0 TO N - 1
    A  = (I * 360 / N) + T
    AX = CX + R * COS(A * 3.14159 / 180) - 16
    AY = CY + R * SIN(A * 3.14159 / 180) - 16
    ' rot matches ring angle + 90 so the ship points outward
    SPRITE STAMP 0, AX, AY, 0, 10, A + 90
  NEXT I

  T = T + 2
  IF T >= 360 THEN T = 0
  VSYNC
LOOP
