# Map / Level File format

Status: **draft v1 — design phase.** No code shipping until two MVP games (vertical shooter + Zelda-lite) consume the format end-to-end.

## Goals

1. **Human-editable + diffable** — JSON in git, no opaque binary blobs.
2. **Layer-aware** — backgrounds, foregrounds, collision, objects all distinct.
3. **Tooling-friendly** — borrow Tiled / LDtk shape so external editors can produce or consume it with minimal mapping.
4. **Versioned** — schema can grow without breaking old maps.
5. **Embeddable in 8bitworkshop IDE** — the existing `map_editor.bas` becomes the canonical editor for v1; later, an external Tiled importer is a non-event.
6. **Fast enough at runtime** — RGC-BASIC parses small JSON in milliseconds; if a real game ever needs sub-frame load times, ship a binary export pass (don't poison the canonical format with binary-think).

## Why JSON-first, not binary

| | JSON | Binary |
|---|---|---|
| Git diff | yes | no |
| Hand-edit tweak | yes | hex editor |
| Version tolerance | drop unknown fields | breaks on layout shift |
| External tools | every editor | you write them |
| Save/load size (10×100 map) | ~3 KB | ~1 KB |
| Parse cost (canvas WASM) | sub-ms | sub-ms |

Binary "wins" only on size — trivial for the kind of maps anyone hand-builds, and irrelevant once gzipped over the wire. JSON canonical, optional `map-pack` script later for shipping bundles.

## Coordinate conventions (pick once, never bend)

- **Origin**: top-left of the map.
- **+X**: right.
- **+Y**: down.
- **Tile coordinates**: integer cells (`col`, `row`).
- **Object coordinates**: pixels (so non-tile-aligned NPCs, projectile spawns, polygon triggers all work). Pixel = `col * tileW`.
- **Display direction is a *camera* concept, not a *file* concept**. A scroll-up shooter sets `camera.start = { x: 0, y: (mapH-viewH)*tileH }` + `camera.scrollDir = "up"`. The map data itself stays origin-top-left. Loaders never branch on origin.

## Versioning

```
"format": 1
```

First field. Loader rejects unknown majors; minor additions are tolerant (drop unknown fields). Bump major only on breaking changes.

## Top-level schema

```json
{
  "format": 1,
  "id": "level1",
  "title": "The Lava Level",
  "author": "ChrisG",
  "description": "Vertical shooter, stage 1, lava theme.",
  "size":     { "cols": 10, "rows": 100 },
  "tileSize": { "w": 32, "h": 32 },
  "tilesets": [
    {
      "id": "walls",
      "src": "walls.png",
      "cellW": 32, "cellH": 32,
      "tiles": {
        "1":  { "solid": true,  "damaging": false },
        "9":  { "solid": false, "kind": "lava", "damaging": true, "damage": 10 },
        "13": { "solid": true,  "kind": "door", "props": { "leadsTo": "level1.b" } }
      },
      "animations": {
        "9": { "frames": [9, 10, 11, 10], "durationMs": 120 }
      }
    }
  ],
  "layers": [
    { "name": "bg",    "type": "tiles",   "tilesetId": "walls", "data": [ ... cols*rows ints ... ] },
    { "name": "fg",    "type": "tiles",   "tilesetId": "walls", "data": [ ... ] },
    { "name": "coll",  "type": "tiles",   "tilesetId": "walls", "data": [ ... ], "visible": false },
    { "name": "obj",   "type": "objects", "objects": [ /* see below */ ] }
  ],
  "camera": {
    "start":     { "x": 0, "y": 3168 },
    "scrollDir": "up",
    "speedPxPerSec": 32,
    "lockX": true
  },
  "props": {
    "music": "lava.xm",
    "parTimeSec": 90,
    "next": "level2"
  }
}
```

Notes on each block:

### `id` vs `title`

- `id`: filename-safe, unique across the project. Used as a foreign key (`next`, `door.leadsTo`, savegame keys). Lowercase, ASCII, hyphens.
- `title`: human-readable. UI display only. Localisable later.

### `size` and `tileSize`

`size` in cells. `tileSize` in pixels. Pixel dimensions of the world = `size.cols * tileSize.w` × `size.rows * tileSize.h`.

### `tilesets`

Array, not single — a Zelda overworld layer + dungeon door layer might use different sheets. Each entry:

- `id` — local key for layers to reference.
- `src` — path to PNG, resolved relative to the map file.
- `cellW`, `cellH` — sheet cell size. Must match the loaded SPRITE LOAD slot.
- `tiles` — sparse map of per-tile metadata, **string-keyed** by *local* tile id (1..N within this sheet; 0 = blank). Saves space when only a handful of tiles need flags.
- `animations` — optional. Keyed by tile id; `frames` is a list of tile ids in the same set; `durationMs` is per-frame. Renderer ticks once a frame.

**External tileset reuse**: a tileset entry may set `"src": "walls.tileset.json"` instead of inlining `tiles`/`animations`. Loader fetches and merges. Lets a Zelda game share one tileset file across 50 dungeon rooms.

### `layers`

Ordered, drawn back-to-front. Two types:

#### `type: "tiles"`

- `tilesetId` — references `tilesets[].id`.
- `data` — flat row-major int array of length `size.cols * size.rows`. Tile id 0 = blank/transparent (matches `TILEMAP DRAW` semantics in RGC-BASIC). Indices ≥ 1 are GIDs into the resolved tileset.
- `visible` — default true. `false` for a collision layer the runtime queries but never paints.
- `parallax` — optional `{ x: 0.5, y: 1.0 }` (planned v1.1, not v1). Per-axis parallax scroll factor.
- `props` — custom layer-level props.

#### `type: "objects"`

- `objects` — list of objects (see next section).
- `visible` — same default semantics; object renderer can skip an invisible spawn-only layer.

### Objects

A single object schema covers **enemies, loot, NPCs, triggers, spawn points, doors, decorations**. Type drives behaviour, geometry drives placement.

```json
{
  "id": 17,
  "type": "enemy",
  "kind": "grunt",
  "shape": "rect",
  "x": 64, "y": 1280, "w": 24, "h": 24,
  "props": {
    "hp": 3, "speed": 80, "drops": "health"
  }
}
```

- `id` — unique within the layer (or unique within the map; pick one and stick to it). Used by triggers to reference (`linkedTo: 17`) and by savegame state (`opened-chest-17`).
- `type` — discriminator. Reserved values: `enemy`, `npc`, `loot`, `door`, `trigger`, `spawn`, `decoration`, `marker`. Anything else is engine-specific.
- `kind` — sub-type free-form (`grunt`, `boss`, `key`, `health`, `crystal`). Engine maps `kind` → spawn template.
- `shape` — `point` (no w/h needed), `rect` (default, needs w/h), `polygon` (`points: [[x1,y1],...]`), `ellipse`. Triggers and zone-of-effect things benefit; most game objects stay rect.
- `x`, `y`, `w`, `h` — pixels. Top-left origin (rect/ellipse) or vertex 0 (polygon).
- `props` — custom dictionary; engine reads what it needs. Free for evolution.

**Door pairing** (Zelda):

```json
{ "id": 5,  "type": "door", "kind": "stairs-down",
  "shape": "rect", "x": 320, "y": 96, "w": 32, "h": 32,
  "props": { "leadsTo": "dungeon-1", "spawnAt": 9 } }
```

`leadsTo` is the target map's `id`; `spawnAt` is the target object id (a `marker` or another `door`) that the player materialises onto.

**Triggers** (vertical shooter spawn-on-camera-cross):

```json
{ "id": 42, "type": "trigger", "kind": "spawn-wave",
  "shape": "rect", "x": 0, "y": 1600, "w": 320, "h": 8,
  "props": { "fires": "wave-3", "once": true } }
```

Runtime fires `wave-3` event when camera or player enters the rect. `once: true` removes the trigger after firing.

**Player spawn**:

```json
{ "id": 1, "type": "spawn", "kind": "player",
  "shape": "point", "x": 160, "y": 3168 }
```

No more "start tile" header field — it's just a well-known object.

### Camera

```json
"camera": {
  "start":          { "x": 0, "y": 3168 },
  "scrollDir":      "up",
  "speedPxPerSec":  32,
  "lockX":          true,
  "lockY":          false,
  "mode":           "auto"
}
```

- `start` in pixels.
- `scrollDir`: `"up" | "down" | "left" | "right" | "free"`.
- `speedPxPerSec`: fixed scroll rate. 0 = player-driven.
- `lockX` / `lockY`: clamp camera axis to map bounds (prevent over-scroll).
- `mode`: `"auto"` (timer-driven, shooter), `"follow"` (centred on player, Zelda free-scroll), `"room"` (snaps to room boundaries on player crossing — classic Zelda 1).

`mode: "room"` opens the door (heh) to **room maps** without changing format: the `obj` layer holds invisible rect objects of `type: "marker"` `kind: "room"` whose `props.id` names each screen — camera snaps to whichever room the player is inside.

### Top-level `props`

Map-wide free-form: `music`, `parTimeSec`, `next`, `theme`, `palette`, etc. Engine reads what it cares about.

## Tile id 0 = blank

Matches `TILEMAP DRAW`. Saves space for sparse maps (most cells of a Zelda overworld's "objects" layer are 0). Don't reserve any other magic ids.

## Per-tile vs per-instance state

Three categories — keep them separated:

| Category | Where it lives | Example |
|---|---|---|
| Static tile property | Tileset's `tiles[id]` | `solid: true` for any wall tile |
| Per-instance map data | Layer `data` array / `objects` list | "this cell is wall id 7" / "enemy 17 is at (64,1280)" |
| Runtime / savegame state | **Separate savegame file**, never the map | "barrel 17 has been smashed" / "player has key 5" |

The map file is the *level design*. The savegame is the *play state*. Conflating the two means every `git diff` of a level becomes meaningless and "reset level" needs custom logic.

## Encoding options (v1.1+, not v1)

- **`encoding: "rle"`** on a tile layer's `data`: alternating `[count, value, count, value, …]`. Wins on sparse Zelda overworlds. v1 = plain int array always; v1.1 adds it as opt-in.
- **`encoding: "base64-gzip"`**: matches Tiled's CSV/base64 layouts. v1.2.
- **External `data: "level1.bg.bin"`**: defer the tile array to a sibling file. v1.2.

Don't ship any of these in v1 — JSON ints are fine for the MVP games and we'd be optimising fiction.

## Loader library plan (`maplib.bas`)

Single library, every demo / game `#INCLUDE`s it. Public surface:

```basic
' Load a map JSON file, populate a parsed dict-style global state.
FUNCTION MapLoad(path$)

' Width / height in cells.
FUNCTION MapW()
FUNCTION MapH()

' Tile id at (col, row, layerName$). 0 if out of bounds.
FUNCTION MapTile(col, row, layerName$)

' Set a tile (live edit / damage runtime).
FUNCTION MapSetTile(col, row, layerName$, tile)

' Iterate objects on a layer, returning each as { id, type$, kind$, x, y, w, h, props$ }.
' Engine pattern: walk once at level load, register per-type with the engine.
FUNCTION MapEachObject(layerName$, callback$)

' Camera helpers.
FUNCTION MapCameraStart()
FUNCTION MapScrollDir$()

' Tileset metadata for SPRITE LOAD.
FUNCTION MapTilesetSrc$(tilesetId$)
FUNCTION MapTileSolid(tilesetId$, tile)
```

Implementation: parse JSON via a simple recursive-descent over the file's bytes (BUFFER + GETBYTE), build flat arrays/dicts in BASIC vars. RGC-BASIC has no native dict; use parallel arrays keyed by string ids, looked up linearly (10–50 entries, fine).

If JSON parsing in BASIC turns out painful, **fallback**: ship a Python build-time `map-compile.py` that emits a `level1.bas` `DATA`-style include with the parsed structure already laid out as BASIC arrays. Author edits JSON; build step pre-bakes BASIC. JSON stays canonical.

## MVP test games

Both are minimum-effort throwaways whose only job is to break the format design.

### MVP-1: Vertical shooter (Xenon II skeleton)

- **Map**: 10×100 cells. Single bg tile layer, single fg tile layer (debris), single obj layer.
- **Camera**: `start: { x:0, y:3168 }, scrollDir: "up", speedPxPerSec: 32, lockX: true, mode: "auto"`.
- **Objects**: ~10 enemy `kind:"grunt"` placed at varying Y; 2 `trigger kind:"spawn-wave"` rectangles at Y=1600 and Y=800; 1 `spawn kind:"player"`; end-of-level `trigger kind:"boss"` at Y=64.
- **Tileset**: 16 tiles, half flagged `solid` (for projectile collision).
- **Engine logic**: scroll camera, fire triggers when camera Y crosses, spawn enemies as objects come into viewport, projectile vs solid-tile collision via `MapTileSolid`.

What this validates: layer drawing with camera, single-axis scroll, trigger firing, object spawn timing, tile flag lookup.

### MVP-2: Zelda-style screen-flip RPG

- **Map**: 32×32 cells. Two tile layers (terrain + decoration). One collision tile layer (`visible: false`). One obj layer with NPCs, doors, room markers.
- **Camera**: `mode: "room"`, `lockX/Y` per room.
- **Objects**: 4×4 grid of `marker kind:"room"` rect objects (each 8×8 cells), one `npc kind:"oldman"` with dialogue prop, one `door kind:"cave"` linking to a second tiny map (8×8) and back.
- **Tileset**: shared overworld + cave tilesets, demonstrates `tilesets[]` array of length >1 with each layer pointing at its own `tilesetId`.
- **Engine logic**: free-scroll restricted to current room rect; transition snaps camera; door teleport across maps; NPC interact reads `props.dialogue`.

What this validates: room-mode camera, multi-tileset map, cross-map references via `id`, layered render with hidden collision, object property dispatch.

### Why both, not one

- Shooter alone misses doors/state/multiple-tilesets/non-grid camera.
- Zelda alone misses single-axis auto-scroll and time-cross triggers.
- Together they touch every field in the schema except v1.1 deferrals (RLE, parallax, animations — animations could go in MVP-2's lava tile if we want to validate).

## Tooling roadmap

| Phase | Item | Notes |
|---|---|---|
| Now | `map_editor.bas` produces v1 JSON | Replace `map.bin` writer. Read existing `map.bin` once with a one-shot importer for legacy demos. |
| Now | `maplib.bas` loader | Used by both MVP games. |
| MVP+1 | Tiled importer (Python) | Most external assets show up as Tiled `.tmj`; one-way convert to our v1. |
| MVP+1 | LDtk importer | Same idea, LDtk's level-pack model maps cleanly to our `id`/`leadsTo`/`next`. |
| Later | `map-pack` binary export | Only when a game ships and load time is on the profiler. |
| Later | Animated tile renderer hook | RGC-BASIC TILEMAP path adds per-cell animation tick; v1.1 format flag. |

## Drop list (things removed from the original draft)

- "Way of defining display direction" — moved to `camera.scrollDir`, kept out of file origin.
- "Start tile" — replaced by `spawn` object.
- "Tile properties: damaged, active, obstacle" — split into static (tileset) vs runtime state (savegame, not map).
- Anonymous "looping" — split into `camera.scrollDir` (none of which loops) and a future `wrap: { x: true }` flag if a torus world is ever needed.

## Open questions to resolve before locking v1

1. ~~**Polygon triggers**~~ — *resolved 2026-04-26: reserved in spec, not implemented in v1. Use tile-flag (e.g. `tiles[id].kind = "water"`) for irregular zones in MVP-era games. Polygon graduates when a real game needs sloped ground / guard cones / non-grid AOE.*
2. ~~**Object id scope**~~ — *resolved 2026-04-26: unique per map (see Decision log).*
3. ~~**Tile id namespace**~~ — *resolved 2026-04-26: per-tileset local ids (see Decision log).*
4. ~~**Custom `props` value types**~~ — *resolved 2026-04-26: flat only, string/number/bool (see Decision log).*
5. ~~**Empty layer omit**~~ — *resolved 2026-04-26: absence-implies-default everywhere (see Decision log).*

## Decision log

(Fill as we go — every "we picked X over Y because Z" lands here so the next person doesn't relitigate.)

- *2026-04-26* — JSON canonical, binary export deferred. Reason: hand-editability dominates, parse cost negligible at our map sizes.
- *2026-04-26* — Top-left origin, +X right, +Y down. Reason: matches screen / image data / Tiled. No file-level "display direction" toggle; that's a camera concern.
- *2026-04-26* — Layer model borrowed from Tiled (tile + object layers, ordered). Reason: existing tooling, mental model already widespread.
- *2026-04-26* — **Tile id namespace: per-tileset local ids**, not Tiled-style global GIDs with `firstGid` offsets. Each tile layer carries `tilesetId` and its `data` array uses ids 1..N within that sheet (0 = blank). Reason: maps cleanly onto RGC-BASIC's `TILEMAP DRAW` (one slot per call = one tileset per layer); inserting/removing tiles in a sheet doesn't renumber other sheets; loader is a direct lookup, no GID range search. Trade-off accepted: a single layer cannot mix tiles from two sheets — author splits into two layers stacked. Tiled importer will unpack global GIDs into per-layer local ids.
- *2026-04-26* — **Polygon shape reserved, not shipped in v1.** `shape: "polygon"` is documented as a future extension; loader rejects it for now. Irregular zones (Link's oddly-shaped pond, lava puddle, fire pit) use **tile-flag** approach instead: paint cells in a tile layer, set `tiles[id].kind = "water"` etc. in the tileset metadata, runtime queries the flag. Reason: keeps v1 implementation small (no point-in-polygon helper, no editor poly tool), matches Zelda 1's own approach, leaves syntax door open for sloped ground / stealth cones when a game actually needs them.
- *2026-04-26* — **Object id scope: unique per map.** A single integer namespace covers every object across all object layers in one map. Reason: cross-layer references like `door.props.spawnAt = 9` or `trigger.props.linkedTo = 17` resolve with one lookup, no `(layerName, objId)` tuple. Cost: when merging two maps, ids may collide and need renumbering — accepted because map-merge is a tooling operation, not a runtime concern.
- *2026-04-26* — **Custom `props` value types: flat only — string, number, bool.** No nested objects or arrays. Reason: keeps the BASIC parser trivial (single-pass key/value), forces authors to model relations through `id` references rather than burying state inside `props`. Patterns like "Link enters shop" / "treasure chest opens" stay clean — shops are objects with `kind: "shop"` + `props.inventory: "shop-1"` (string id pointing at a separate inventory file or another object), chests are `kind: "chest"` + `props.contents: "key"` + savegame tracks opened state. If a real use case forces nested values later, bump format version and revisit.
- *2026-04-26* — **Empty / missing layers: absence implies default.** No layer is required. Missing `coll` layer = nothing collides. Missing `obj` layer = no entities. Loader fills with empty defaults; engine code branches `IF MapLayerExists("coll") THEN ...`. Reason: smallest possible "hello world" map, every demo doesn't need a stub collision layer to satisfy a schema, and adding new optional layers in future versions doesn't break old maps.
