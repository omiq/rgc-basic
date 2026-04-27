# MVP-2 Zelda-lite — assets in this folder

Using OpenGameArt **"Zelda-like Tilesets and Sprites"** by ArMM1998
(originally https://opengameart.org/content/zelda-like-tilesets-and-sprites).
Tiles are **16×16**, character/NPC sprites are **16×32**. Verify
license before public release (typically CC0 for this pack).

Reference images with numbered cells exist alongside each sheet:
`Overworld_ref.png`, `cave_ref.png`, `objects_ref.png`,
`character_ref_16x32.png`, `NPC_test_ref.png`. Regenerate with
`/tmp/tile_ref.py`.

## Sheet inventory

| File              | Size     | Cell  | Grid    | Tiles |
|-------------------|----------|-------|---------|-------|
| `Overworld.png`   | 640×576  | 16×16 | 40×36   | 1440  |
| `cave.png`        | 640×400  | 16×16 | 40×25   | 1000  |
| `Inner.png`       | 640×400  | 16×16 | 40×25   | 1000  |
| `objects.png`     | 528×320  | 16×16 | 33×20   | 660   |
| `log.png`         | 192×128  | 16×16 | 12×8    | 96    |
| `font.png`        | 240×144  | —     | —       | —     |
| `character.png`   | 272×256  | 16×32 | 17×8    | 136   |
| `NPC_test.png`    | 64×128   | 16×32 | 4×4     | 16    |

## MVP-1 picks (subject to user revision)

### Overworld tile ids
- Walkable: grass `1` (also 4,5,6 = grass variants)
- Path/dirt: `49`
- Sand: `204`
- **solid** (water + tree + rock + walls): water family `17–22, 57–62`,
  rock `15, 28`, building wall — TBD when authored
- **door** (warp to cave): TBD pick (guess `67`)

### Cave tile ids
- Floor: `2` (darkgray)
- **solid** (wall): `162, 163, 164, 168` family + water `282`
- **stairs** (warp to overworld): TBD pick (guess `168`)

### Sprite picks
- **Player** (`character.png` 16×32):
  - down idle: frame 1 (used in MVP-1)
  - down walk: frames 1–4
  - left/up/right/sword: TBD (rows 2, 3, 4, 5)
- **NPC** (`NPC_test.png` 16×32): frame 1 (single bald guy)
- **Enemy**: not in pack — placeholder = tint NPC red, or skip

## Map design

| Decision | Value |
|---|---|
| Overworld map size | 32 × 32 cells (512 × 512 px world) |
| Room size | 20 × 12 cells = 320 × 192 px (full viewport less HUD strip) |
| Room grid | overworld is 1.6 × 2.6 rooms — adjusted to 1 large area for MVP-1 |
| Cave map | `level1_cave.bas`, 20 × 12 cells (single room) |
| Door pairing | one overworld door tile → cave entry; cave stair tile → back |
| Combat | sword swipe on bump (deferred — MVP-1 is exploration only) |
| NPC interact | walk-into-NPC opens dialogue text in HUD; SPACE dismisses |
| Camera mode | `room` — snap to current room on player crossing boundary |
| HUD | top 24 px strip: hearts (lives) + dialogue text |

## What this MVP validates in `docs/map-format.md`

- multi-tileset map (`tilesets[]` length 2; layers reference `tilesetId`)
- multi-layer rendering (terrain + decoration + collision)
- `camera.mode = "room"` snap behaviour
- door pairing via `props.leadsTo` + `props.spawnAt`
- objects with `kind: npc | door | spawn`

Polygon collision shapes — explicitly deferred (per format spec).
