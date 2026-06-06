' ============================================================
'  gfx_dice_map_demo - 5x5 rolled-dice dungeon map preview
'
'  Simulates 25 physical dice tipped onto a 5x5 grid so you can
'  judge whether the six UV-printed faces tile into coherent
'  random maps. Each "roll" picks BOTH a random face (1-6) AND a
'  random rotation (0/90/180/270) - because a real square tile
'  dropped on a grid lands at one of four orientations, and that
'  rotation is what decides whether a straight corridor runs
'  across or down, whether a bend hooks left or right, etc.
'
'  Faces (examples/side_N.png, 32x32 each):
'    1 = straight corridor      4 = crossroad corridor
'    2 = right-angle corridor    5 = room w/ mystery box
'    3 = T-section               6 = room w/ 4 exits
'
'  Rotation only renders on the raylib backend (basic-gfx). On
'  canvas / WASM the arg is accepted but ignored, so tiles show
'  upright there.
'
'  Keys: SPACE / R = re-roll all 25 dice    Q = quit
' ============================================================

' Load each die face into its own sprite slot 1..6.
SPRITE LOAD 1, "side_1.png"
SPRITE LOAD 2, "side_2.png"
SPRITE LOAD 3, "side_3.png"
SPRITE LOAD 4, "side_4.png"
SPRITE LOAD 5, "side_5.png"
SPRITE LOAD 6, "side_6.png"

' Seed the RNG from the jiffy timer so each run differs.
R = RND(-TI)

TILE = 32                  ' native face size
COLS = 5
ROWS = 5
GW   = COLS * TILE         ' 160
GH   = ROWS * TILE         ' 160
OX   = (320 - GW) / 2      ' centre horizontally -> 80
OY   = 16                  ' leave room for title above

' Per-cell rolled state: face value and rotation.
DIM FACE(24)
DIM ROT(24)

' Pick a random landing rotation for a given face. Only the
' DIRECTIONAL tiles get turned; rotation-symmetric tiles (and
' ones with a centred non-directional detail like the mystery
' box) stay upright, where a quarter-turn is either a no-op or
' just looks wrong.
'   1 straight : 0 or 90   (runs across or down)
'   2 bend     : full 0/90/180/270
'   3 T-section: full 0/90/180/270
'   4 cross / 5 box room / 6 four-exit room : symmetric -> 0
FUNCTION RotFor(f)
  IF f = 1 THEN RETURN INT(RND(1) * 2) * 90
  IF f = 2 THEN RETURN INT(RND(1) * 4) * 90
  IF f = 3 THEN RETURN INT(RND(1) * 4) * 90
  RETURN 0
END FUNCTION

' Roll all 25 dice: each gets a random face 1..6 and a face-aware
' landing rotation. Fills the global FACE()/ROT() arrays and
' returns 0 (called for its side effect).
FUNCTION Roll()
  FOR I = 0 TO ROWS * COLS - 1
    FACE(I) = 1 + INT(RND(1) * 6)
    ROT(I)  = RotFor(FACE(I))
  NEXT I
  RETURN 0
END FUNCTION

Z = Roll()                 ' initial roll

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN Z = Roll()
  IF KEYPRESS(ASC("R")) THEN Z = Roll()

  CLS

  ' Backing panel so the laid-out tiles read as one map.
  COLORRGB 18, 18, 28
  FILLRECT OX - 2, OY - 2 TO OX + GW + 1, OY + GH + 1

  ' Stamp the 25 rolled dice tightly edge-to-edge.
  FOR ROW = 0 TO ROWS - 1
    FOR COL = 0 TO COLS - 1
      I = ROW * COLS + COL
      X = OX + COL * TILE
      Y = OY + ROW * TILE
      SPRITE STAMP FACE(I), X, Y, 0, 1, ROT(I)
    NEXT COL
  NEXT ROW

  ' Title + legend + controls.
  COLORRGB 255, 255, 255
  DRAWTEXT 88, 4, "DUNGEON DICE - 5x5 MAP", 1
  COLORRGB 150, 200, 255
  DRAWTEXT 4, 182, "1 STRAIGHT  2 BEND  3 TEE  4 CROSS", 1
  DRAWTEXT 4, 190, "5 BOX ROOM  6 4-EXIT     SPACE=ROLL  Q=QUIT", 1

  VSYNC
LOOP

SCREEN 0
CLS
PRINT "Rolled 25 dice. Adjust your faces and re-roll to test map flow."
END
