' ============================================================
'  gfx_dice_map_demo - 5x5 rolled-dice dungeon map preview
'
'  Simulates 25 physical dice tipped onto a 5x5 grid to check
'  whether the six UV-printed corridor faces tile into coherent
'  random maps - and how much better the maps get if the
'  rotatable corridor pieces (faces 1-3) are turned to line up
'  their exits instead of landing at random.
'
'  EDGE MODEL --------------------------------------------------
'  Every tile is a square; each of its 4 sides is an exit or a
'  wall, packed as a 4-bit mask:  N=1  E=2  S=4  W=8.
'  Two neighbours CONNECT only when the shared side is an exit
'  on BOTH tiles. Rotating a tile 90 deg clockwise cycles the
'  bits N->E->S->W (see Rot1). Base masks (calibrated to the art):
'    1 straight  = N+S       = 5   (rotatable: 5,10)
'    2 bend      = W+S       = 12  (rotatable: 12,9,3,6)
'    3 T-section = W+S+E     = 14  (rotatable: 14,13,11,7)
'    4 crossroad = N+E+S+W   = 15  (symmetric - never rotated)
'    5 box room  = N+E+S+W   = 15  (symmetric)
'    6 4-exit rm = N+E+S+W   = 15  (symmetric)
'
'  The physical roll fixes each tile's FACE. Only the rotation
'  of faces 1-3 is free, so that's all the optimiser touches.
'
'  MODES -------------------------------------------------------
'    RANDOM    - each rotatable tile lands at a random angle
'    OPTIMISED - hill-climb + restarts picks rotations that
'                maximise matched exits (see Optimise)
'  The scoreboard shows LINKS (matched doorways) and REACH (size
'  of the largest connected region via flood fill) so you can
'  compare the two on the very same roll.
'
'  NOTE on the dialect: only function PARAMETERS are local; every
'  other variable a function touches is global. So nested calls
'  must not share plain variable names. We dodge this by baking
'  the per-cell masks into MASK() once (SyncMasks) and having the
'  hot functions read that array instead of recomputing masks
'  mid-call. The Has* readers are safe (parameter-only leaves).
'
'  Keys: SPACE/R = new roll   O = toggle RANDOM/OPTIMISED   Q = quit
' ============================================================

' Load each die face into its own sprite slot 1..6.
SPRITE LOAD 1, "side_1.png"
SPRITE LOAD 2, "side_2.png"
SPRITE LOAD 3, "side_3.png"
SPRITE LOAD 4, "side_4.png"
SPRITE LOAD 5, "side_5.png"
SPRITE LOAD 6, "side_6.png"

SEED = RND(-TI)            ' seed RNG from the jiffy timer

TILE = 32
COLS = 5
ROWS = 5
NCELL = COLS * ROWS
GW   = COLS * TILE
GH   = ROWS * TILE
OX   = (320 - GW) / 2
OY   = 16

' Base exit masks per face (calibrated to the PNG art at 0 deg).
DIM BASE(6)
BASE(1) = 5  : BASE(2) = 12 : BASE(3) = 14
BASE(4) = 15 : BASE(5) = 15 : BASE(6) = 15

' Per-cell rolled state. ROT() is in quarter-turns (0..3).
DIM FACE(24)
DIM ROT(24)
DIM MASK(24)               ' current exit mask per cell (SyncMasks)
DIM BESTROT(24)            ' optimiser scratch
DIM VISIT(24)              ' flood-fill scratch
DIM STACK(24)              ' flood-fill scratch

MODE   = 1                 ' 0 = RANDOM, 1 = OPTIMISED
GLINKS = 0                 ' matched doorways (computed per roll)
GREACH = 0                 ' largest connected region (per roll)

' ---- exit bit accessors (parameter-only leaves; safe to nest) ----
FUNCTION HasN(m)
  RETURN m MOD 2
END FUNCTION
FUNCTION HasE(m)
  RETURN INT(m / 2) MOD 2
END FUNCTION
FUNCTION HasS(m)
  RETURN INT(m / 4) MOD 2
END FUNCTION
FUNCTION HasW(m)
  RETURN INT(m / 8) MOD 2
END FUNCTION

' Rotate a mask 90 deg clockwise: opening at N moves to E, etc.
' new N <- old W,  new E <- old N,  new S <- old E,  new W <- old S
FUNCTION Rot1(m)
  RETURN HasW(m) * 1 + HasN(m) * 2 + HasE(m) * 4 + HasS(m) * 8
END FUNCTION

' Mask of a base after k quarter-turns. WHILE (not FOR) because
' FOR 1 TO 0 runs once in this dialect - it tests at the bottom.
FUNCTION MaskOf(base, k)
  mm = base
  jj = 0
  WHILE jj < k
    mm = Rot1(mm)
    jj = jj + 1
  WEND
  RETURN mm
END FUNCTION

' Rebuild MASK() from the current FACE()/ROT(). Call after any
' change to rotations before scoring or drawing.
FUNCTION SyncMasks()
  FOR i = 0 TO NCELL - 1
    MASK(i) = MaskOf(BASE(FACE(i)), ROT(i))
  NEXT i
  RETURN 0
END FUNCTION

' How many distinct rotations a face has (1 = symmetric, fixed).
FUNCTION NRot(f)
  IF f = 1 THEN RETURN 2
  IF f = 2 THEN RETURN 4
  IF f = 3 THEN RETURN 4
  RETURN 1
END FUNCTION

' Matched doorways on cell i's edges vs its current neighbours.
' Reads MASK() (array) + Has* (leaves) only - no mask recompute.
FUNCTION LocalScore(i)
  c  = i MOD COLS
  r  = INT(i / COLS)
  mi = MASK(i)
  ls = 0
  IF c > 0        THEN ls = ls + HasW(mi) * HasE(MASK(i - 1))
  IF c < COLS - 1 THEN ls = ls + HasE(mi) * HasW(MASK(i + 1))
  IF r > 0        THEN ls = ls + HasN(mi) * HasS(MASK(i - COLS))
  IF r < ROWS - 1 THEN ls = ls + HasS(mi) * HasN(MASK(i + COLS))
  RETURN ls
END FUNCTION

' Total matched doorways across the grid (each counted once: only
' the East and South edge of every cell).
FUNCTION ScoreGrid()
  sc = 0
  FOR i = 0 TO NCELL - 1
    c  = i MOD COLS
    r  = INT(i / COLS)
    mi = MASK(i)
    IF c < COLS - 1 THEN sc = sc + HasE(mi) * HasW(MASK(i + 1))
    IF r < ROWS - 1 THEN sc = sc + HasS(mi) * HasN(MASK(i + COLS))
  NEXT i
  RETURN sc
END FUNCTION

' Size of the largest connected region via flood fill over the
' connection graph. A good proxy for "how navigable is the map".
FUNCTION LargestComp()
  FOR i = 0 TO NCELL - 1
    VISIT(i) = 0
  NEXT i
  big = 0
  FOR seed = 0 TO NCELL - 1
    IF VISIT(seed) = 0 THEN
      sp = 1
      STACK(0) = seed
      VISIT(seed) = 1
      cnt = 0
      WHILE sp > 0
        sp  = sp - 1
        cur = STACK(sp)
        cnt = cnt + 1
        c   = cur MOD COLS
        r   = INT(cur / COLS)
        mc  = MASK(cur)
        IF c < COLS - 1 THEN
          IF HasE(mc) * HasW(MASK(cur + 1)) = 1 THEN
            IF VISIT(cur + 1) = 0 THEN
              VISIT(cur + 1) = 1
              STACK(sp) = cur + 1
              sp = sp + 1
            END IF
          END IF
        END IF
        IF c > 0 THEN
          IF HasW(mc) * HasE(MASK(cur - 1)) = 1 THEN
            IF VISIT(cur - 1) = 0 THEN
              VISIT(cur - 1) = 1
              STACK(sp) = cur - 1
              sp = sp + 1
            END IF
          END IF
        END IF
        IF r < ROWS - 1 THEN
          IF HasS(mc) * HasN(MASK(cur + COLS)) = 1 THEN
            IF VISIT(cur + COLS) = 0 THEN
              VISIT(cur + COLS) = 1
              STACK(sp) = cur + COLS
              sp = sp + 1
            END IF
          END IF
        END IF
        IF r > 0 THEN
          IF HasN(mc) * HasS(MASK(cur - COLS)) = 1 THEN
            IF VISIT(cur - COLS) = 0 THEN
              VISIT(cur - COLS) = 1
              STACK(sp) = cur - COLS
              sp = sp + 1
            END IF
          END IF
        END IF
      WEND
      IF cnt > big THEN big = cnt
    END IF
  NEXT seed
  RETURN big
END FUNCTION

' Random rotation for every cell (respecting each face's symmetry).
FUNCTION Randomise()
  FOR i = 0 TO NCELL - 1
    ROT(i) = INT(RND(1) * NRot(FACE(i)))
  NEXT i
  RETURN 0
END FUNCTION

' Hill-climb with random restarts: repeatedly set each rotatable
' tile to the rotation that maximises matches with its current
' neighbours, until a full pass changes nothing. Keep the best of
' several restarts to dodge local optima. Mutates ROT().
FUNCTION Optimise()
  best = -1
  FOR rs = 0 TO 4
    Z = Randomise()
    Z = SyncMasks()
    improved = 1
    WHILE improved = 1
      improved = 0
      FOR i = 0 TO NCELL - 1
        nr = NRot(FACE(i))
        IF nr > 1 THEN
          orig = ROT(i)
          bl   = LocalScore(i)
          br   = orig
          FOR k = 0 TO nr - 1
            ROT(i)  = k
            MASK(i) = MaskOf(BASE(FACE(i)), k)
            l = LocalScore(i)
            IF l > bl THEN
              bl = l
              br = k
            END IF
          NEXT k
          ROT(i)  = br
          MASK(i) = MaskOf(BASE(FACE(i)), br)
          IF br <> orig THEN improved = 1
        END IF
      NEXT i
    WEND
    tot = ScoreGrid()
    IF tot > best THEN
      best = tot
      FOR i = 0 TO NCELL - 1
        BESTROT(i) = ROT(i)
      NEXT i
    END IF
  NEXT rs
  FOR i = 0 TO NCELL - 1
    ROT(i) = BESTROT(i)
  NEXT i
  RETURN best
END FUNCTION

' Apply the current MODE to the current faces, then refresh metrics.
FUNCTION Apply()
  IF MODE = 0 THEN
    Z = Randomise()
  ELSE
    Z = Optimise()
  END IF
  Z = SyncMasks()
  GLINKS = ScoreGrid()
  GREACH = LargestComp()
  RETURN 0
END FUNCTION

' Roll all 25 dice (random faces), then lay them out per MODE.
FUNCTION Roll()
  FOR i = 0 TO NCELL - 1
    FACE(i) = 1 + INT(RND(1) * 6)
  NEXT i
  Z = Apply()
  RETURN 0
END FUNCTION

Z = Roll()                 ' initial roll

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN Z = Roll()
  IF KEYPRESS(ASC("R")) THEN Z = Roll()
  ' O re-lays the SAME faces under the other mode = direct A/B test.
  IF KEYPRESS(ASC("O")) THEN MODE = 1 - MODE : Z = Apply()

  CLS

  ' Backing panel so the laid-out tiles read as one map.
  COLORRGB 18, 18, 28
  FILLRECT OX - 2, OY - 2 TO OX + GW + 1, OY + GH + 1

  ' Stamp the 25 rolled dice tightly edge-to-edge.
  FOR ROW = 0 TO ROWS - 1
    FOR COL = 0 TO COLS - 1
      I = ROW * COLS + COL
      SPRITE STAMP FACE(I), OX + COL * TILE, OY + ROW * TILE, 0, 1, ROT(I) * 90
    NEXT COL
  NEXT ROW

  ' Title + live scoreboard.
  COLORRGB 255, 255, 255
  DRAWTEXT 92, 4, "DUNGEON DICE - 5x5 MAP", 1
  IF MODE = 0 THEN
    COLORRGB 255, 180, 120
    DRAWTEXT 4, 178, "MODE RANDOM   "
  ELSE
    COLORRGB 120, 255, 160
    DRAWTEXT 4, 178, "MODE OPTIMISED"
  END IF
  COLORRGB 200, 220, 255
  DRAWTEXT 92, 178, "LINKS " + STR$(GLINKS) + "  REACH " + STR$(GREACH) + "/25"
  COLORRGB 150, 200, 255
  DRAWTEXT 4, 190, "SPACE=ROLL  O=MODE  Q=QUIT", 1

  VSYNC
LOOP

SCREEN 0
CLS
PRINT "Rolled 25 dice. O toggles random vs optimised rotation."
END
