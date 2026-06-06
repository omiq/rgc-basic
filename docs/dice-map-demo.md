# RGC BASIC — how `gfx_dice_map_demo` works

An annotated walk-through of [`examples/gfx_dice_map_demo.bas`](https://github.com/omiq/rgc-basic/blob/main/examples/gfx_dice_map_demo.bas)
([open in IDE](https://ide.retrogamecoders.com/?file=gfx_dice_map_demo.bas&platform=rgc-basic)),
written for someone who knows BASIC but has never seen this program.

It assumes nothing about the program itself — only that you can read
`FOR`/`WHILE`, `FUNCTION`, arrays, and `IF`. By the end you should be
able to change the grid size, re-calibrate the tiles for new artwork,
or swap in a different map-quality metric.

---

## 1. What the program is for

Chris is printing six dungeon-corridor tiles onto the faces of physical
dice (`examples/side_1.png` … `side_6.png`):

| Face | Meaning |
|---|---|
| 1 | straight corridor |
| 2 | right-angle (bend) corridor |
| 3 | T-section |
| 4 | crossroad (4-way) corridor |
| 5 | room with a mystery box |
| 6 | room with 4 exits |

The idea: roll 25 dice, lay them out in a 5×5 grid, and you've got a
random dungeon map. The program is a **digital dry-run** of that — it
rolls 25 virtual dice, lays out the matching PNGs, and answers two
questions:

1. Do the tiles actually join up into a navigable map?
2. How much *better* does the map get if you're allowed to **rotate**
   the corridor pieces to line their exits up, instead of leaving them
   at whatever angle they landed?

That second question is the heart of the program.

---

## 2. The key idea: a tile is four edges

Everything else follows from one modelling decision. Forget the
pictures; think of each tile as a square with **four sides** — North,
East, South, West — and each side is either an **exit** (a corridor
opening) or a **wall**.

Two tiles that sit next to each other **connect** only if the side they
share is an exit on *both* of them. An exit facing a wall is a dead end;
an exit facing the edge of the grid is wasted.

We pack those four yes/no facts into a single number using one bit each:

```
N = 1     E = 2     S = 4     W = 8
```

So a value of `5` means `1 + 4` = exits on **N and S** (a vertical
straight corridor). A value of `15` means `1+2+4+8` = all four sides
open (a crossroad or a room). This 0–15 number is the tile's **mask**.

### Calibrating the masks to the artwork

The base mask is "what does this PNG look like at 0° rotation", read
straight off the art:

| Face | Picture at 0° | Exits | Mask | `BASE()` |
|---|---|---|---|---|
| 1 | straight | N + S | `5` | `BASE(1)=5` |
| 2 | bend | W + S | `12` | `BASE(2)=12` |
| 3 | T-section | W + S + E | `14` | `BASE(3)=14` |
| 4 | crossroad | N+E+S+W | `15` | `BASE(4)=15` |
| 5 | box room | N+E+S+W | `15` | `BASE(5)=15` |
| 6 | 4-exit room | N+E+S+W | `15` | `BASE(6)=15` |

```basic
DIM BASE(6)
BASE(1) = 5  : BASE(2) = 12 : BASE(3) = 14
BASE(4) = 15 : BASE(5) = 15 : BASE(6) = 15
```

> **If you redraw the tiles, this table is the one thing you must
> update.** The whole program is correct only relative to these numbers.
> Faces 4–6 are `15` (open on every side) which is why rotating them
> does nothing — important later.

### Reading individual bits

Four tiny helper functions pull one bit back out of a mask using
integer division and `MOD` (no bitwise operators needed):

```basic
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
```

`HasE(5)` is `0` (a vertical straight has no east exit); `HasN(5)` is
`1`. These return 1 or 0, which lets us multiply them — `HasE(a) * HasW(b)`
is `1` exactly when both are open. That trick is used everywhere instead
of an `AND`.

---

## 3. Rotation is just shifting the bits

When you turn a tile 90° clockwise, the exit that was on North moves to
East, East→South, South→West, West→North. So rotating a *mask* is a
fixed reshuffle of its four bits:

```basic
' new N <- old W,  new E <- old N,  new S <- old E,  new W <- old S
FUNCTION Rot1(m)
  RETURN HasW(m) * 1 + HasN(m) * 2 + HasE(m) * 4 + HasS(m) * 8
END FUNCTION
```

`MaskOf(base, k)` applies that `k` times to get the mask after `k`
quarter-turns:

```basic
FUNCTION MaskOf(base, k)
  mm = base
  jj = 0
  WHILE jj < k
    mm = Rot1(mm)
    jj = jj + 1
  WEND
  RETURN mm
END FUNCTION
```

Worked through, the rotations of each rotatable face are:

- straight `5` → `5, 10` (vertical, horizontal — then it repeats)
- bend `12` → `12, 9, 3, 6` (four corners)
- T `14` → `14, 13, 11, 7` (four directions the stem can face)

> **Why `WHILE` and not `FOR jj = 1 TO k`?** In RGC-BASIC a `FOR`
> loop tests its limit at the *bottom*, so `FOR jj = 1 TO 0` runs
> **once** rather than zero times. `MaskOf(base, 0)` must return the
> base untouched, so the loop has to be able to run zero times — hence
> `WHILE`.

`NRot(f)` says how many *distinct* orientations a face has, so the rest
of the program never bothers rotating a symmetric tile:

```basic
FUNCTION NRot(f)
  IF f = 1 THEN RETURN 2     ' straight: 2 useful angles
  IF f = 2 THEN RETURN 4     ' bend: 4
  IF f = 3 THEN RETURN 4     ' T: 4
  RETURN 1                   ' 4/5/6 are symmetric: only 1
END FUNCTION
```

---

## 4. How the grid is stored

The 5×5 grid is held in flat arrays, indexed `0..24`, where cell
`i = row * COLS + col`:

| Array | Holds |
|---|---|
| `FACE(i)` | which die face (1–6) landed on this cell |
| `ROT(i)` | its rotation, in **quarter-turns** 0–3 |
| `MASK(i)` | the resulting exit mask (kept in sync, see §6) |

`FACE` is fixed by the physical roll. `ROT` is the only thing we get to
choose, and only for faces 1–3.

---

## 5. Scoring a map

Two numbers describe map quality.

### LINKS — how many doorways line up

`ScoreGrid()` counts every interior edge where both tiles have a
matching exit. To avoid counting each shared edge twice, it only looks
at each cell's **East** and **South** neighbour:

```basic
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
```

`HasE(mi) * HasW(MASK(i+1))` is `1` only when this cell opens east *and*
the cell to its right opens west — a real doorway.

### REACH — how much of the map you can actually walk

LINKS can be high while the map is still split into separate islands.
The number a player feels is **how many of the 25 cells are reachable
from one another**. `LargestComp()` answers that with a classic
flood-fill:

- Treat the grid as a graph: two cells are joined by an edge when they
  share a matching doorway (the same `HasE*HasW` test).
- From each unvisited cell, walk every connected cell using an explicit
  stack (`STACK()` / `sp`) and a visited marker (`VISIT()`), counting
  how big that island is.
- Return the size of the **largest** island.

```basic
WHILE sp > 0
  sp  = sp - 1
  cur = STACK(sp)
  cnt = cnt + 1
  ...
  IF c < COLS - 1 THEN
    IF HasE(mc) * HasW(MASK(cur + 1)) = 1 THEN
      IF VISIT(cur + 1) = 0 THEN
        VISIT(cur + 1) = 1
        STACK(sp) = cur + 1
        sp = sp + 1
      END IF
    END IF
  END IF
  ' ... same for W, S, N ...
WEND
```

A `REACH` of `25/25` means the whole dungeon is one connected space.

---

## 6. The one BASIC-dialect gotcha that shapes the code

You'll notice the scoring functions read `MASK(i)` directly rather than
calling `MaskOf(...)` on the spot. There's a concrete reason.

**In RGC-BASIC, only a function's *parameters* are local. Every other
variable a function uses is global.** That means if function A uses a
variable called `r`, and A calls function B which also uses `r`, B
silently overwrites A's `r`.

`LocalScore` (below) uses `r` for "row". If it called `MaskOf` in the
middle — and `MaskOf` also used a variable called `r` — the row value
would be clobbered mid-function and the boundary checks would read
garbage (in practice: negative array indices and a crash).

The fix is to compute every cell's mask **once** into the `MASK()` array
and have the hot functions read the array (array access can't clobber
anything) instead of recomputing through nested calls:

```basic
FUNCTION SyncMasks()
  FOR i = 0 TO NCELL - 1
    MASK(i) = MaskOf(BASE(FACE(i)), ROT(i))
  NEXT i
  RETURN 0
END FUNCTION
```

`SyncMasks` is called after *any* change to `ROT()` and before any
scoring. The only functions that still call `MaskOf` are `SyncMasks`
and the optimiser's inner loop — and neither of them uses the names
`mm`/`jj` that `MaskOf` works with, so nothing collides.

> Takeaway for your own RGC-BASIC code: **don't reuse plain variable
> names across functions that call each other.** Give each function
> uniquely-named locals, or pass state through arrays.

---

## 7. The optimiser

This is the payoff. The faces are fixed; we want to rotate pieces 1–3 so
the most doorways line up.

### `LocalScore` — one tile's contribution

For a single cell, how many of its (up to four) edges currently match?

```basic
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
```

### `Optimise` — hill-climbing with restarts

A full brute-force search (every rotation of every tile) is huge, but we
don't need it. Because the score is just a sum over edges, a simple
**local search** gets most of the benefit:

> Repeatedly visit each rotatable tile and turn it to whichever of its
> 2–4 orientations matches its current neighbours best. Keep sweeping
> until a whole pass changes nothing.

That's *hill-climbing*. Its weakness is getting stuck in a "local
optimum" — a layout where no single tile can improve, but a different
starting point would have done better. The cure is cheap: do it several
times from different random starts and keep the best (`best` /
`BESTROT()`):

```basic
FUNCTION Optimise()
  best = -1
  FOR rs = 0 TO 4                 ' 5 random restarts
    Z = Randomise()
    Z = SyncMasks()
    improved = 1
    WHILE improved = 1
      improved = 0
      FOR i = 0 TO NCELL - 1
        nr = NRot(FACE(i))
        IF nr > 1 THEN             ' skip symmetric faces 4-6
          orig = ROT(i)
          bl   = LocalScore(i)
          br   = orig
          FOR k = 0 TO nr - 1      ' try each orientation
            ROT(i)  = k
            MASK(i) = MaskOf(BASE(FACE(i)), k)
            l = LocalScore(i)
            IF l > bl THEN
              bl = l
              br = k
            END IF
          NEXT k
          ROT(i)  = br             ' keep the best one
          MASK(i) = MaskOf(BASE(FACE(i)), br)
          IF br <> orig THEN improved = 1
        END IF
      NEXT i
    WEND
    tot = ScoreGrid()
    IF tot > best THEN             ' remember the best restart
      best = tot
      FOR i = 0 TO NCELL - 1
        BESTROT(i) = ROT(i)
      NEXT i
    END IF
  NEXT rs
  FOR i = 0 TO NCELL - 1           ' restore the winner
    ROT(i) = BESTROT(i)
  NEXT i
  RETURN best
END FUNCTION
```

Measured over 300 random rolls, this lifts average `REACH` from about
**20.6/25** (random rotation) to **24.5/25** (optimised) — usually the
entire dungeon becomes one connected space. It can't *guarantee* a
fully-connected map (the dice might simply not provide the exits), but
it reliably beats leaving the tiles where they fell.

---

## 8. Tying it together

Three small functions form the pipeline:

```basic
FUNCTION Randomise()    ' give every cell a random legal rotation
FUNCTION Apply()        ' run the current MODE, then refresh LINKS/REACH
FUNCTION Roll()         ' new random FACE() for all 25, then Apply()
```

`Apply()` is the hub:

```basic
FUNCTION Apply()
  IF MODE = 0 THEN
    Z = Randomise()      ' MODE 0 = leave them as they fell
  ELSE
    Z = Optimise()       ' MODE 1 = turn 1-3 to line up
  END IF
  Z = SyncMasks()
  GLINKS = ScoreGrid()
  GREACH = LargestComp()
  RETURN 0
END FUNCTION
```

`MODE` is the toggle between the two experiments, and `GLINKS` /
`GREACH` are globals the draw loop displays.

---

## 9. The main loop and rendering

After an initial `Z = Roll()`, the program sits in a standard game loop:

```basic
DO
  IF KEYDOWN(ASC("Q"))  THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN Z = Roll()           ' new roll
  IF KEYPRESS(ASC("R")) THEN Z = Roll()
  IF KEYPRESS(ASC("O")) THEN MODE = 1 - MODE : Z = Apply()  ' A/B toggle

  CLS
  ' dark backing panel, then 25 sprites stamped edge-to-edge:
  FOR ROW = 0 TO ROWS - 1
    FOR COL = 0 TO COLS - 1
      I = ROW * COLS + COL
      SPRITE STAMP FACE(I), OX + COL * TILE, OY + ROW * TILE, 0, 1, ROT(I) * 90
    NEXT COL
  NEXT ROW
  ' title + scoreboard (MODE, LINKS, REACH) ...
  VSYNC
LOOP
```

Two things worth noting:

- **`O` re-lays the *same* roll** under the other mode (it calls
  `Apply()`, not `Roll()`), so you can flip back and forth and watch
  exactly which tiles the optimiser turned and how `REACH` changes.
- **`SPRITE STAMP`'s 6th argument is the rotation in degrees**, so we
  render `ROT(I) * 90`. The maths assumes positive degrees rotate
  *clockwise* (matching `Rot1`). If you ever see a high `LINKS` score
  but the corridors visually don't meet, your build rotates the other
  way — render `((4 - ROT(I)) MOD 4) * 90` instead.

Rotation only renders on the raylib backend (`basic-gfx`); the canvas /
WASM builds accept the angle but draw tiles upright.

---

## 10. Ideas for extending it

- **Bigger maps:** change `COLS`/`ROWS`/`NCELL` and the `DIM` sizes.
  Everything else is written in terms of those.
- **Weighted dice:** bias `FACE(i) = 1 + INT(RND(1) * 6)` toward rooms
  or corridors to see how the mix changes connectivity.
- **A better objective:** the optimiser maximises *doorways*. You could
  instead optimise `REACH` directly, or add a small penalty for exits
  that point off the grid (wasted corridors).
- **Provably optimal layout:** for a 5×5 grid an exact answer is
  reachable with a row-by-row dynamic program over the 4⁵ possible
  orientation combinations of a row. Overkill here, but a fun exercise.

---

*Companion file:* [`examples/gfx_dice_map_demo.bas`](https://github.com/omiq/rgc-basic/blob/main/examples/gfx_dice_map_demo.bas).
Run it with `./basic-gfx examples/gfx_dice_map_demo.bas` — `SPACE` rolls,
`O` toggles random vs optimised, `Q` quits.
