# RGC BASIC — RPG tutorial: objects, loot, traps, enemies

Companion to [`map-format.md`](map-format.md). Where `map-format.md` defines the JSON schema, this page defines the **gameplay vocabulary** — what to put inside the `obj` layer to build a Zelda-class RPG: spawns, doors, NPCs, loot, weapons, spells, traps, power-ups, McGuffins, enemies, AI, and attack patterns.

The reference implementation is [`examples/rpg/rpg.bas`](../examples/rpg/rpg.bas), which currently handles `spawn` / `door` / `npc`. The other types described below are documented for future tutorial chapters and your own extensions — engine code lands in the same `RenderObjects` / `Update*` / `HandleCollide` pipeline `rpg.bas` already uses.

---

## 1. Where objects live

`MAPLOAD` reads the map JSON and populates parallel BASIC arrays from one specific `layers[]` entry — the one with `"type": "objects"`:

```json
{
  "name": "obj",
  "type": "objects",
  "objects": [ /* one entry per game object */ ]
}
```

Object **coordinates are pixels** (top-left origin), not tile cells. To place a 16×16 object at column 10, row 5 of a 16×16 grid: `x = 160`, `y = 80`.

After load, the engine reads:

| BASIC global | Source | Notes |
|---|---|---|
| `MAP_OBJ_COUNT` | total entries | DIM destination arrays at least this big |
| `MAP_OBJ_TYPE$(N)` | `objects[N].type` | discriminator |
| `MAP_OBJ_KIND$(N)` | `objects[N].kind` | sprite / template selector |
| `MAP_OBJ_X(N)` | `objects[N].x` | px |
| `MAP_OBJ_Y(N)` | `objects[N].y` | px |
| `MAP_OBJ_W(N)` | `objects[N].w` | px (0 if `shape: point`) |
| `MAP_OBJ_H(N)` | `objects[N].h` | px |
| `MAP_OBJ_ID(N)` | `objects[N].id` | save-game / cross-ref key |

`props` is **not** auto-exposed in arrays — `MAPLOAD` keeps the raw JSON, and engines that need a `prop` call `map_json_str(...)` / `map_json_num(...)` from C-side helpers (or do the read in BASIC by walking the file again). For most engines, encode the data you need into `kind` so you don't need `props` at all.

---

## 2. Object schema (every type)

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

| Field | Purpose | Values |
|-------|---------|--------|
| `id` | Unique per map. Foreign key for `door.spawnAt`, savegame state, trigger linkages | int |
| `type` | Discriminator — engine dispatches behaviour on this | `spawn`, `door`, `npc`, `enemy`, `loot`, `trap`, `trigger`, `marker`, `decoration`, … |
| `kind` | Sub-type, free-form. Engine maps `kind` → spawn template (sprite slot, default props) | string (`player`, `cave`, `old_man`, `rupee`, `wooden_sword`, `octorok`, `boss`) |
| `shape` | Geometry | `point` (no w/h), `rect` (default), `polygon` (`points: [[x,y],...]`), `ellipse` |
| `x, y, w, h` | Pixels. Top-left origin (rect/ellipse) or vertex 0 (polygon). `point` ignores w/h | int |
| `props` | Custom dictionary. Engine reads what it needs; safe to add fields without breaking older loaders | object |

**Rule of thumb:** `type` answers *what category of thing*; `kind` answers *which one*; `props` answers *what state does it carry*.

---

## 3. The three already-shipping types

### `spawn` — player start point

- **Purpose**: tells `SetSpawn()` where the player materialises on level entry.
- **Required fields**: `type`, `kind: "player"`, `shape: "point"`, `x`, `y`.
- **Engine reads**: `MAP_OBJ_X` / `MAP_OBJ_Y` of the entry where `MAP_OBJ_TYPE$ = "spawn"`.
- **Example**:
  ```json
  { "id": 1, "type": "spawn", "kind": "player",
    "shape": "point", "x": 64, "y": 448 }
  ```

### `door` — auto-warp into another map (or marker)

- **Purpose**: walk-into trigger that calls `SwapLevel()` to load a different JSON map. AABB-tested against the player's foot rect every frame.
- **Required fields**: `type`, `kind` (target name — engine uses this to pick the destination JSON), `shape: "rect"`, `x, y, w, h`, `props.leadsTo`, `props.spawnAt`.
- **Engine reads**: `MAP_OBJ_KIND$` for routing (`"cave"` → `level1_cave.json`); `props.leadsTo` is the target map's top-level `id`; `props.spawnAt` is the target object `id` to land on (a `marker` or another `door`).
- **Important**: pair doors so the destination has a return-door at the spawn point — `rpg.bas` uses a `JUST_WARPED` flag to stop ping-pong on overlap.
- **Example**:
  ```json
  { "id": 2, "type": "door", "kind": "cave",
    "shape": "rect", "x": 256, "y": 128, "w": 16, "h": 16,
    "props": { "leadsTo": "level1-cave", "spawnAt": 1 } }
  ```

### `npc` — non-player character with dialogue

- **Purpose**: rendered as 16×32 sprite (`character3.png`-class sheet); SPACE-near triggers dialog box. Wander AI is built-in (see `UpdateNpcs()` in `rpg.bas`).
- **Required fields**: `type`, `kind` (sprite/template name), `shape: "rect"`, `x, y, w, h`, `props.dialogue` (line displayed on interact).
- **Engine reads**: `MAP_OBJ_KIND$` to pick sprite slot (currently hard-coded to slot 2 in `rpg.bas`); `props.dialogue` is read directly from JSON via `map_json_str` (or hard-coded — `rpg.bas` v1 has a single hard-coded line; reading `props.dialogue` is the natural next step).
- **Example**:
  ```json
  { "id": 3, "type": "npc", "kind": "old_man",
    "shape": "rect", "x": 128, "y": 384, "w": 16, "h": 32,
    "props": { "dialogue": "OLD MAN: TAKE THIS GUIDE TO THE CAVE." } }
  ```

---

## 4. Loot — pickups player walks into

### Coins / gems / keys / bombs / arrows

- **Purpose**: bump-on-touch consumable. AABB-collide → remove from active list → bump player counter.
- **Required fields**: `type: "loot"`, `kind`, `shape: "rect"` (or `point`), `x, y, w, h`, `props.value`, optional `props.respawn`.
- **Common `kind` values**: `rupee`, `coin`, `gem`, `key`, `bomb`, `arrow`, `bombs5`.
- **Engine reads**: `kind` for sprite + counter to bump; `props.value` for amount; `props.respawn` (bool) for re-appear after leaving room.
- **Example**:
  ```json
  { "id": 10, "type": "loot", "kind": "rupee",
    "shape": "rect", "x": 96, "y": 96, "w": 16, "h": 16,
    "props": { "value": 5, "respawn": false } }
  ```

### Container — chest, jar, gravestone

- **Purpose**: SPACE-near to open; reveals contents + sets persistent flag.
- **Required fields**: `type: "loot"`, `kind: "chest"`, `shape: "rect"`, `x, y, w, h`, `props.contains` (loot kind), `props.opened` (bool, init false), optional `props.needs` (key kind).
- **Engine reads**: `props.opened` flips on use; persist via savegame keyed by `mapId + "/" + id`.
- **Example**:
  ```json
  { "id": 11, "type": "loot", "kind": "chest",
    "shape": "rect", "x": 192, "y": 64, "w": 16, "h": 16,
    "props": { "contains": "key", "opened": false, "needs": "small_key" } }
  ```

---

## 5. Weapons & equipment

- **Purpose**: pickup → set inventory flag → update HUD. Weapons differ from consumable loot by **persistent** effect.
- **Required fields**: `type: "loot"`, `kind: "weapon"` (or `shield`, `bow`, `boomerang`), `shape: "point"`, `x, y`, `props.weapon` (item id), `props.damage`, `props.range`.
- **Engine reads**: on pickup, set BASIC flag (`HAS_SWORD = 1`), refresh HUD; sprite removed.
- **Example**:
  ```json
  { "id": 20, "type": "loot", "kind": "weapon",
    "shape": "point", "x": 240, "y": 200,
    "props": { "weapon": "wooden_sword", "damage": 1, "range": 12 } }
  ```

---

## 6. Spells, potions, consumables

### Potion — one-shot effect

- **Purpose**: pickup → apply effect (`heal`, `mana`, `speed`, `invuln`, `freeze`) for `props.amount` HP / `props.duration` ms.
- **Required fields**: `type: "loot"`, `kind: "potion"`, `shape: "point"`, `x, y`, `props.effect`, `props.amount`, optional `props.stack`.
- **Engine reads**: `props.effect` chooses BASIC code path; `props.amount` is the size.
- **Example**:
  ```json
  { "id": 30, "type": "loot", "kind": "potion",
    "shape": "point", "x": 64, "y": 320,
    "props": { "effect": "heal", "amount": 3, "stack": 5 } }
  ```

### Spell — learn-once permanent ability

- **Purpose**: pickup teaches the spell; player can cast at `props.cost` mana per use.
- **Required fields**: `type: "loot"`, `kind: "spell"`, `shape: "point"`, `x, y`, `props.spell`, `props.cost`.
- **Common `props.spell`**: `fireball`, `heal`, `freeze`, `lightning`, `shield`, `blink`.
- **Example**:
  ```json
  { "id": 31, "type": "loot", "kind": "spell",
    "shape": "point", "x": 80, "y": 320,
    "props": { "spell": "fireball", "cost": 10 } }
  ```

---

## 7. Traps

### Spike, swinging blade, falling rock

- **Purpose**: AABB-on-touch damage while `props.active = true`. Cycle defines **when** active.
- **Required fields**: `type: "trap"`, `kind`, `shape: "rect"`, `x, y, w, h`, `props.damage`, `props.active`, `props.cycle`.
- **`props.cycle` values**:
  - `"always"` — always armed.
  - `"timed"` — armed for `props.activeMs` then off for `props.idleMs`. `props.phase` (0..1) staggers groups.
  - `"pressure"` — fires on first stand-on; persistent until reset.
  - `"arrow"` — periodic, spawns projectile in `props.dir` (`up`/`down`/`left`/`right`).
- **Example**:
  ```json
  { "id": 40, "type": "trap", "kind": "spike",
    "shape": "rect", "x": 144, "y": 160, "w": 16, "h": 16,
    "props": { "damage": 1, "active": true, "cycle": "always" } }
  ```

### Damaging tile (cheaper alternative — no object)

- **Purpose**: lava, swamp, electric floor — every tile of the type damages on standing. Doesn't need a per-cell object.
- **How**: in tileset section of map JSON, mark the tile id `damaging`:
  ```json
  "tilesets": [{ "id": "overworld", "src": "Overworld.png", "cellW": 16, "cellH": 16,
    "tiles": {
      "9": { "solid": false, "kind": "lava", "damaging": true, "damage": 1 }
    }
  }]
  ```
- Engine reads tile id at player's foot → checks `damaging` flag in tileset metadata. Faster than scanning an objects layer.

---

## 8. Health & power-ups

### Heart — temporary heal

- **Purpose**: refill HP by `props.heal`.
- **Required fields**: `type: "loot"`, `kind: "heart"`, `shape: "point"`, `x, y`, `props.heal`.
- **Example**:
  ```json
  { "id": 50, "type": "loot", "kind": "heart",
    "shape": "point", "x": 32, "y": 200,
    "props": { "heal": 1 } }
  ```

### Heart container — permanent +1 max HP

- **Purpose**: increase player's `LIVES_MAX` (or hearts count) permanently.
- **Required fields**: `type: "loot"`, `kind: "heart_container"`, `shape: "point"`, `x, y`, `props.max_heal`.
- **Persistence**: must persist (`savegame: "heart_container_3"` or similar) — never respawn.
- **Example**:
  ```json
  { "id": 51, "type": "loot", "kind": "heart_container",
    "shape": "point", "x": 32, "y": 220,
    "props": { "max_heal": 1 } }
  ```

### Power-up — gameplay modifier

- **Purpose**: bigger inventory, magic meter unlock, compass, map.
- **Required fields**: `type: "loot"`, `kind: "powerup"`, `shape: "point"`, `x, y`, `props.effect`.
- **Common `props.effect`**: `bigger_bag`, `magic_meter`, `compass`, `map`, `boots`, `flippers`.
- **Example**:
  ```json
  { "id": 52, "type": "loot", "kind": "powerup",
    "shape": "point", "x": 100, "y": 100,
    "props": { "effect": "flippers" } }
  ```

---

## 9. McGuffin / quest items

- **Purpose**: story-critical item that gates progression. Permanent, never respawns, engraved into savegame.
- **Required fields**: `type: "loot"`, `kind: "quest"`, `shape: "point"`, `x, y`, `props.item`, `props.required_for` (gate id), `props.savegame` (persistent key).
- **Example**:
  ```json
  { "id": 60, "type": "loot", "kind": "quest",
    "shape": "point", "x": 200, "y": 100,
    "props": { "item": "tri_force_piece_3",
               "required_for": "final_door",
               "savegame": "quest_3_done" } }
  ```

---

## 10. Markers & triggers

### Marker — invisible reference point

- **Purpose**: unrendered object camera / engine code reads. Used by `camera.mode = "room"` (Zelda-1 snap-on-cross), music swap zones, save points, fast-travel anchors.
- **Required fields**: `type: "marker"`, `kind`, `shape: "rect"` or `"point"`, `x, y`, optional `w, h`, `props` for whatever the consumer needs.
- **Example** (room boundary):
  ```json
  { "id": 70, "type": "marker", "kind": "room",
    "shape": "rect", "x": 0, "y": 0, "w": 320, "h": 200,
    "props": { "name": "throne_room", "music": "boss_theme" } }
  ```

### Trigger — fire event on enter

- **Purpose**: zone-of-effect that calls a named event handler when player or camera crosses the rect.
- **Required fields**: `type: "trigger"`, `kind`, `shape: "rect"`, `x, y, w, h`, `props.fires`, optional `props.once`.
- **`once: true`** removes the trigger after firing.
- **Example**:
  ```json
  { "id": 80, "type": "trigger", "kind": "spawn_wave",
    "shape": "rect", "x": 0, "y": 600, "w": 320, "h": 8,
    "props": { "fires": "wave_3", "once": true } }
  ```

---

## 11. Enemies — schema

```json
{ "id": 100, "type": "enemy", "kind": "octorok",
  "shape": "rect", "x": 128, "y": 256, "w": 16, "h": 16,
  "props": { "hp": 1, "speed": 1, "ai": "wander",
             "drops": "heart", "damage": 1,
             "patrol_radius": 64 } }
```

Standard `props`:

| Prop | Use |
|------|-----|
| `hp` | hit points — kills on 0 |
| `speed` | px per frame |
| `damage` | contact damage to player |
| `ai` | behaviour preset (see § 12) |
| `drops` | loot `kind` on death (`heart`, `rupee`, `nothing`) |
| `respawn` | re-appear on room re-entry (default false for bosses, true for grunts) |
| `aggro_range` | px until chase begins |
| `attack_cooldown_ms` | between attacks |
| `xp` | optional, for level-up systems |

Engine maintains per-enemy state arrays (`ENEMY_HP(N)`, `ENEMY_X(N)`, `ENEMY_AI_STATE(N)` …) populated from `MAP_OBJ_*` after `MAPLOAD`, mirroring the `InitNpcs()` pattern in `rpg.bas`.

---

## 12. AI presets — `props.ai` values

Pick one preset per enemy. The engine has one BASIC `FUNCTION` per preset, dispatched on `ENEMY_AI$(N)`.

| `ai` | Pattern | Use for |
|------|---------|---------|
| `idle` | stand still, attack on contact | spike, plant, statue |
| `wander` | random dir every N frames, stop on wall | chick, slime, octorok |
| `patrol` | A→B→A, 2 waypoints in `props.path` | guard, beam emitter |
| `chase` | move toward player when `dist < aggro_range` | wolf, zombie |
| `chase_los` | chase only if line-of-sight clear (no walls between) | smarter wolf |
| `flee` | inverse of chase | rabbit, civilian |
| `shoot` | stationary, fire projectile every cooldown_ms | octorok, archer |
| `shoot_chase` | chase + fire | knight |
| `circle` | orbit player at `radius`, fire tangentially | wisp, ghost |
| `dash` | wait → telegraph → lunge → recover | leever, charger |
| `bounce` | move in straight line, reverse on collision | bouncing skull, projectile |
| `formation` | hold rank in group, leader has own AI | bat swarm, soldier squad |
| `boss_phase` | switch pattern at hp thresholds in `props.phases` | boss |

---

## 13. Movement primitives (compose into AI)

Reusable helpers — every AI preset above is built from these.

| Primitive | Code shape | Used by |
|-----------|------------|---------|
| **toward(target)** | `dx = SGN(tx - x) * speed` | chase, homing |
| **away(target)** | `dx = -SGN(tx - x) * speed` | flee |
| **wander** | pick dir 0..3, walk N frames, repeat | wander, patrol |
| **bresenham_path** | walk along precomputed waypoint list | patrol, scripted |
| **sin_oscillate** | `x = home_x + SIN(t * freq) * amp` | floating ghost, mine |
| **homing** | rotate velocity vector toward player by max turn rate | seeking missile |
| **collision_slide** | try X then Y so wall hits don't lock | every grounded enemy (matches `rpg.bas HandleInput`) |

---

## 14. Attack patterns

| Pattern | How |
|---------|-----|
| **Contact** | AABB-vs-player, deal `damage` on touch, knockback player by `props.knockback` px |
| **Melee swing** | telegraph frame (sprite swap, ~6 frames) → spawn hitbox in front of self for N frames → recover |
| **Projectile** | spawn `type: "enemy_proj"` object every cooldown, vel = facing dir |
| **Spread** | 3 / 5 / 8 projectiles in fan pattern |
| **Aimed** | projectile vel = `(player - self) / dist * speed` — straight at the player at the moment of fire |
| **Wave** | projectile y = base_y + SIN(t) * amp (sine-wave bullet) |
| **Bomb** | projectile lands → spawns `trap`-style explosion area for N frames |
| **Charge** | telegraph 30 frames → high-speed straight dash → stop at wall |
| **Summon** | spawn 2-3 minions then idle |

`enemy_proj` objects share schema with enemies but typically use `props.lifetime_ms`, `props.vx`, `props.vy`, and despawn on wall hit. Treat as ordinary enemies in the update pipeline; player-vs-proj is just AABB collision.

---

## 15. Boss pattern — phase encoding

Bosses are enemies with `ai: "boss_phase"` and a `props.phases[]` array. Engine picks the active phase by current HP and swaps AI/cooldowns live.

```json
{ "id": 999, "type": "enemy", "kind": "ganon",
  "shape": "rect", "x": 160, "y": 120, "w": 32, "h": 32,
  "props": {
    "hp": 30,
    "ai": "boss_phase",
    "phases": [
      { "until_hp": 20, "ai": "shoot",       "cooldown_ms": 1500 },
      { "until_hp": 10, "ai": "chase_shoot", "cooldown_ms": 800,  "speed": 2 },
      { "until_hp": 0,  "ai": "dash",        "telegraph_ms": 600, "speed": 4 }
    ],
    "drops": "heart_container"
  } }
```

Each phase reads as a fresh `props` mini-bundle. `until_hp` is the HP threshold at which the phase **ends** (next phase begins). Final phase has `until_hp: 0` meaning "down to dead".

---

## 16. Persistence — what to track per-`id`

Some flags need to survive level reload / save. Engine maintains a savegame dict keyed by `mapId + "/" + objId`.

| Flag | Set when | Read when |
|------|----------|-----------|
| `dead` | enemy hp ≤ 0 | InitEnemies on level entry — skip dead-and-no-respawn |
| `opened` | chest opens, door unlocks | render (don't draw closed lid) + InitObjects (don't re-roll loot) |
| `triggered` | one-shot trigger fires | InitTriggers — skip placing already-fired |
| `state` | door-open level (0..3), switch position | render + interaction |
| `picked` | quest item / heart container collected | InitObjects — skip placing |

Save file format = whatever fits the platform. Native: `OPEN` / `PRINT#`. Browser WASM: write to MEMFS file then `DOWNLOAD path$`. Browser session-only: hold in BASIC arrays cleared on tab close.

---

## 17. Where this code lands in `rpg.bas`

The current `rpg.bas` already has the right pipeline shape — every new type slots into one of these existing functions:

| New type | Add to |
|----------|--------|
| `loot` | `InitLoot()` (mirror `InitNpcs`), `RenderObjects` (extra branch), `HandleInput` (AABB pickup test) |
| `trap` | `UpdateTraps()` (cycle state), `RenderObjects`, `HandleInput` (damage on overlap) |
| `enemy` | `InitEnemies()`, `UpdateEnemies()` (per-AI dispatch), `RenderObjects`, `HandleInput` (player-enemy AABB), `HandleAttack()` (player-vs-enemy weapon hit) |
| `enemy_proj` | spawn from `UpdateEnemies` shoot patterns; tick + render in `UpdateProjectiles()`; despawn on wall hit |
| `marker` | not rendered; consumed by camera / music / save logic |
| `trigger` | tick in `UpdateTriggers()`, fire named event handler on overlap |

Per-type DIM arrays go next to the existing NPC ones near the top of `rpg.bas`. Keep parallel arrays per type (`LOOT_X(N)`, `LOOT_Y(N)`, `LOOT_KIND$(N)`, …) — easier than tagged unions in BASIC.

---

## 18. Tutorial chapter mapping (suggested)

| Chapter | Adds | Demo level |
|---------|------|-----------|
| 1 | `spawn` + `door` + map switching | overworld + cave (already in repo) |
| 2 | `npc` with `props.dialogue` | add second NPC with own line |
| 3 | `loot` (rupee, key, chest) | drop pickups, count in HUD |
| 4 | `loot` weapons + inventory | wooden sword, swing animation, melee hitbox |
| 5 | `trap` (spike, arrow) + tile-level `damaging` | trap corridor in cave |
| 6 | `enemy` with `ai: "wander"` + contact damage | grunts in overworld |
| 7 | `enemy` with `ai: "shoot"` + projectiles | octoroks shooting rocks |
| 8 | `loot` spells, mana meter | fireball spell, mana potions |
| 9 | `marker` for room camera + boss-fight room | locked-door miniboss |
| 10 | `enemy` with `ai: "boss_phase"` | final boss with 3 phases |
| 11 | McGuffin `loot.quest` + locked endgame | tri-force piece quest gate |
| 12 | Save / load via `MAPSAVE` + savegame dict | persistent dead-flag, picked-up items |

Each chapter adds **one BASIC function** plus a few JSON object entries. The engine pipeline (`HandleInput` / `Update*` / `Render*` / `VSYNC`) doesn't need to change shape; only its `IF MAP_OBJ_TYPE$ = …` branches grow.

---

## See also

- [`map-format.md`](map-format.md) — JSON schema spec, decision log, v1.1+ deferrals.
- [`overlay-plane.md`](overlay-plane.md) — HUD plane (life bar, dialog box) above the world.
- [`examples/rpg/rpg.bas`](../examples/rpg/rpg.bas) — production engine for chapters 1-2.
- [`examples/rpg/level1_overworld.json`](../examples/rpg/level1_overworld.json) — canonical example of `obj` layer with spawn + door + npc.
- [retrodocs Level authoring](https://docs.retrogamecoders.com/basic/rgc-basic/level-authoring/) — JSON vs BASIC builder, migration path.
