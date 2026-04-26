# MVP-2 Zelda-lite — asset spec

Drop assets in this directory (`examples/rpg/`). Manifest format
matches `examples/shooter/manifest.txt`. Once delivered, the engine
+ level files get scaffolded as `rpg.bas`, `level1.bas`,
`level1_cave.bas`, all consuming `maplib.bas` (per
`docs/map-format.md`).

## Required

### Tilesets — exercises multi-tileset support

```
overworld.png   256x128  cellW=32 cellH=32    32 tiles: grass, water, sand,
                                              path, tree, rock, fence, sign,
                                              flowers, etc.
cave.png        256x128  cellW=32 cellH=32    32 tiles: stone floor, wall,
                                              door, stairs, torch, chest,
                                              cracked-wall variant.
```

### Player + NPCs + enemies

```
link.png        160x32   cellW=32 cellH=32    5 frames: idle + up + down +
                                              left + right (one frame each;
                                              animate later).
npc.png         32x32                         single friendly NPC sprite
                                              (old man / merchant).
enemy.png       64x32    cellW=32 cellH=32    1 enemy, 2-frame walk anim
                                              (slime / octorok).
```

## Optional (skip if shipping faster matters)

```
items.png       64x16    cellW=16 cellH=16    4 items: heart, key, sword,
                                              gem (chest drops + HUD).
heart.png       8x8                           HUD heart pip (lives display).
effects.png     32x32                         sword-slash / sparkle one-shot.
```

## Per-tileset metadata to provide

For each tileset, list the **local tile ids** that fall into each
category. (Per the format spec, ids are 1-based local to each sheet;
0 = blank.)

### `overworld.png`

- **solid** (block player + projectiles): _list ids_
- **damaging** + damage value (lava / spikes — optional): _list ids_
- **kind: door** — id of any tile that triggers map transition on
  walk-into: _list ids_

### `cave.png`

- **solid**: _list ids_
- **kind: door** (back to overworld): _list ids_
- **kind: chest** (interactable, drops items): _list ids_

## Design choices to confirm before scaffold

| Decision | Default proposal |
|---|---|
| Overworld map size | 32 × 32 cells (1024 × 1024 px world) |
| Room size | 8 × 8 cells → 4 × 4 grid = 16 rooms (Zelda 1 screen-flip) |
| Cave map | separate file `level1_cave.bas`, 8 × 8 cells (single room) |
| Door pairing | one overworld door → cave entry; cave stairs → back to overworld |
| Combat | sword swipe on bump — kills enemy if facing it (no projectiles) |
| NPC interact | walk-into-NPC opens dialogue text in HUD strip; E or SPACE dismisses |
| Camera mode | `room` — snap to current 8×8 room on player crossing boundary |
| HUD | top 24 px strip: hearts (lives) + dialogue text |

## What this MVP validates in `docs/map-format.md`

- **multi-tileset map** (`tilesets[]` length 2; layers reference
  `tilesetId`)
- **multi-layer rendering** (terrain + decoration + hidden collision)
- **camera.mode = "room"** snap behaviour
- **door pairing** via `props.leadsTo` + `props.spawnAt`
- **objects** with `kind: npc | enemy | door | chest | spawn`
- **per-instance state** vs static tile flag (player has key 5 lives
  in savegame domain; tile.solid is static tileset metadata)

Together with MVP-1 shooter, every concept in v1 of the format
(except polygon shapes — explicitly deferred) gets exercised.
