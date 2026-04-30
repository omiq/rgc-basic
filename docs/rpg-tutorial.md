# RGC BASIC — RPG tutorial: objects, loot, traps, enemies

Companion to the [`map-format.md`](map-format.md). Where the spec defines the JSON schema, this page defines the **gameplay vocabulary** — what to put inside the `obj` layer to build a Zelda-class RPG: spawns, doors, NPCs, loot, weapons, spells, traps, power-ups, McGuffins, enemies, AI, and attack patterns.

The reference implementation is [`examples/rpg/rpg.bas`](https://github.com/omiq/rgc-basic/blob/main/examples/rpg/rpg.bas) ([open in IDE](https://ide.retrogamecoders.com/?file=rpg/rpg.bas&platform=rgc-basic)), which currently handles `spawn` / `door` / `npc`. The other types described below are documented for future tutorial chapters and your own extensions — engine code lands in the same `RenderObjects` / `Update*` / `HandleCollide` pipeline `rpg.bas` already uses.

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
| `kind` | Sub-type, free-form. Engine maps `kind` → spawn template (sprite slot, default props) | string (`player`, `cave`, `old_man`, `coin`, `wooden_sword`, `octorok`, `boss`) |
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
- **Common `kind` values**: `coin`, `gem`, `key`, `bomb`, `arrow`, `bombs5`.
- **Engine reads**: `kind` for sprite + counter to bump; `props.value` for amount; `props.respawn` (bool) for re-appear after leaving room.
- **Example**:
  ```json
  { "id": 10, "type": "loot", "kind": "coin",
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
| `drops` | loot `kind` on death (`heart`, `coin`, `nothing`) |
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
| 3 | `loot` (coin, key, chest) | drop pickups, count in HUD |
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

## 19. HUD authoring

Full reference: [Graphics — HUD authoring](https://docs.retrogamecoders.com/basic/rgc-basic/graphics-raylib/#hud-authoring-panel-png-attribute-icons). Demo: [`examples/hud_demo.bas`](https://github.com/omiq/rgc-basic/blob/main/examples/hud_demo.bas) ([open in IDE](https://ide.retrogamecoders.com/?file=hud_demo.bas&platform=rgc-basic)).

Quick rules for the Zelda-style strip at the top of `rpg.bas`:

- **`SCREEN 2` (or `SCREEN 4`)** — required for `OVERLAY` redirect. `SCREEN 1` / `SCREEN 3` need the HUD painted directly onto the active plane after the world.
- **Panel** — single PNG at framebuffer width (320 or 640). Load via `IMAGE CREATE` + `IMAGE LOAD` (RGBA, alpha preserved) and `IMAGE BLEND` into the overlay each frame.
- **Icons** — pack as 16×16 tile sheet, load with `SPRITE LOAD slot, "icons.png", 16, 16`, draw with `SPRITE STAMP`.
- **Counters** — mix `SPRITE STAMP` icons with `DRAWTEXT` numbers ("x3", "x12").
- **Z order** — world tiles 0 → world sprites 50 → player 200 → HUD panel 250 → HUD icons 260 → overlay text on top.
- **Asset preload** — list every `.png` referenced (panel + icon sheet + any JSON tileset) in an `ASSET_HINT$` array of literal strings so the IDE preloader stages them into MEMFS.

Track in BASIC globals: `HEARTS`, `HEARTS_MAX`, `KEYS`, `COINS`, `AREA$`, `DIALOG$`. Bump them from loot pickups (§ 4) and damage triggers (§ 7); the HUD function reads and renders without owning state.

---

## 20. State machine + attract mode + dev launch

A real game needs more than one mode — title screen, gameplay, pause, game-over, victory. The cleanest pattern in BASIC is one `STATE` integer + a snapshotted-dispatch master loop. Reference implementation: `examples/rpg/rpg.bas` (§17 of this tutorial maps each function to a state). [Open in IDE](https://ide.retrogamecoders.com/?file=rpg/rpg.bas&platform=rgc-basic).

### State constants

```basic
STATE_TITLE    = 0      ' attract screen, waits for SPACE/ENTER
STATE_PLAYING  = 1      ' normal gameplay (frame loop ticks the world)
STATE_PAUSED   = 2      ' P toggle — overlay drawn, world frozen
STATE_GAMEOVER = 3      ' LIVES = 0 — ENTER returns to title
STATE_WON      = 4      ' end-of-quest screen — ENTER returns to title
STATE = STATE_TITLE
```

Add more as your game grows: `STATE_INVENTORY`, `STATE_SHOP`, `STATE_CUTSCENE`. One integer, one source of truth.

### Master loop — snapshot pattern

```basic
DO
  IF KEYDOWN(KQ) THEN EXIT
  S = STATE                              ' snapshot once per frame

  IF S = STATE_TITLE THEN
    RenderTitle()
    IF KEYPRESS(KSPACE) THEN StartGame()
    IF KEYPRESS(KENTER) THEN StartGame()
  END IF

  IF S = STATE_PLAYING THEN
    HandleInput() : HandleInteract() : CheckDoor()
    UpdateNpcs()  : UpdateCamera()    : RenderFrame()
    IF KEYPRESS(KP) THEN STATE = STATE_PAUSED
    IF LIVES <= 0 THEN STATE = STATE_GAMEOVER
  END IF

  IF S = STATE_PAUSED THEN
    RenderFrame()                        ' draw frozen world below
    RenderPauseOverlay()
    IF KEYPRESS(KP) THEN STATE = STATE_PLAYING
  END IF

  ' ... STATE_GAMEOVER, STATE_WON ...
  VSYNC
LOOP
```

**Why snapshot?** Without it, a state transition mid-frame (`StartGame()` sets `STATE = STATE_PLAYING`) would let the next `IF` block also fire in the same iteration — title-render then game-tick in one frame. Snapshotting `S = STATE` at the top means transitions take effect on the next `VSYNC`-bounded frame.

> **Note:** This pattern predates `ELSE IF` support. With `ELSE IF` (rgc-basic 2.1+) the master loop can be written as a single chain — `IF S = STATE_TITLE THEN … ELSE IF S = STATE_PLAYING THEN … ELSE IF … END IF` — which is shorter but equivalent. The snapshot pattern still works in both styles.

### Attract mode — `welcome.png` + pulse text

```basic
TITLE_HAS_ART = 0
IF FILEEXISTS("welcome.png") THEN
  IMAGE CREATE 10, 320, 200
  IMAGE LOAD 10, "welcome.png"
  TITLE_HAS_ART = 1
END IF

FUNCTION RenderTitle()
  CLS
  IF TITLE_HAS_ART = 1 THEN
    IMAGE BLEND 10, 0, 0, 320, 200 TO 0, 0, 0
  ELSE
    BACKGROUNDRGB 10, 10, 32 : CLS
    COLORRGB 255, 240, 80
    DRAWTEXT 80, 60, "MY RPG", 1, -1, 0, 2     ' 2x scale
  END IF
  ' Breathing prompt — TI ticks at 60Hz, sin-modulate the alpha so
  ' the text fades in and out without dropping a single pixel.
  PULSE = (SIN(TI / 12.0) + 1.0) * 0.5
  ALPHA_BYTE = INT(160 + PULSE * 95)
  COLORRGB 255, 255, 255, ALPHA_BYTE
  DRAWTEXT 80, 168, "PRESS SPACE TO START"
END FUNCTION
```

**`FILEEXISTS` gate** lets the program run before the artwork is drawn — falls back to a coloured backdrop + placeholder text. Same pattern works for any optional asset (custom font, splash music, etc.).

### Dev launch — skip to a specific map

Iterating on a level you can't reach without walking 3 screens is painful. Add a constant pair near the top:

```basic
DEV_SKIP_TITLE = 0           ' flip to 1 to skip the title screen
DEV_MAP$ = "overworld"       ' or "cave"
DEV_X = -1                   ' -1 = use map's spawn point
DEV_Y = -1
```

Then early in startup:

```basic
IF DEV_SKIP_TITLE = 1 THEN StartGame()       ' StartGame respects DEV_*
```

`StartGame()` reads `DEV_MAP$` to choose the JSON, `DEV_X / DEV_Y` to override the spawn:

```basic
FUNCTION StartGame()
  IF DEV_MAP$ = "cave" THEN
    LEVEL$ = "cave" : TILE_SLOT = 3 : MAPLOAD "level1_cave.json"
  ELSE
    LEVEL$ = "overworld" : TILE_SLOT = 0 : MAPLOAD "level1_overworld.json"
  END IF
  IF DEV_X >= 0 AND DEV_Y >= 0 THEN
    PX = DEV_X : PY = DEV_Y
  ELSE
    SetSpawn()
  END IF
  InitNpcs()
  LIVES = 3 : PALIVE = 1 : DIALOG$ = ""
  STATE = STATE_PLAYING
END FUNCTION
```

### Native CLI override (basic-gfx only)

`ARG$()` exposes command-line args on native builds. Wire them straight into the dev constants:

```basic
IF ARGC() > 0 AND ARG$(1) <> "" THEN
  DEV_SKIP_TITLE = 1
  DEV_MAP$ = ARG$(1)
  IF ARGC() >= 3 THEN
    DEV_X = VAL(ARG$(2))
    DEV_Y = VAL(ARG$(3))
  END IF
END IF
```

Now from the shell:

```bash
./basic-gfx examples/rpg/rpg.bas                 # normal: title screen
./basic-gfx examples/rpg/rpg.bas cave            # jump to cave at default spawn
./basic-gfx examples/rpg/rpg.bas overworld 64 96 # jump to overworld at (64, 96)
```

`ARG$(1)` is `""` in browser WASM — toggle the `DEV_SKIP_TITLE` constant for IDE testing. URL query parameters into `ARG$` is a future IDE wiring; not yet exposed.

### Game-over + reset

`StartGame()` is also the reset path — calling it from `STATE_GAMEOVER` re-runs the spawn setup, restores `LIVES`, clears dialog state. Keep it idempotent.

```basic
IF S = STATE_GAMEOVER THEN
  RenderFrame()
  RenderGameOverOverlay()
  IF KEYPRESS(KENTER) THEN STATE = STATE_TITLE
END IF
```

Re-show the title rather than re-running `StartGame()` directly so the player sees the attract loop and chooses to retry intentionally.

### Where each state lives

| State | Drawn by | Input handled by | Exits to |
|-------|----------|------------------|----------|
| TITLE | `RenderTitle()` | SPACE/ENTER → `StartGame()` | PLAYING |
| PLAYING | `RenderFrame()` (existing) | `HandleInput()`, P → PAUSED, LIVES≤0 → GAMEOVER | PAUSED / GAMEOVER / WON |
| PAUSED | `RenderFrame()` + `RenderPauseOverlay()` | P/SPACE → PLAYING | PLAYING |
| GAMEOVER | `RenderFrame()` + `RenderGameOverOverlay()` | ENTER → TITLE | TITLE |
| WON | `RenderFrame()` + `RenderWonOverlay()` | ENTER → TITLE | TITLE |

Pause / gameover / won overlays use the OVERLAY plane (`SCREEN 2/4` requirement) so they sit above the world without clobbering it. The overlay panel + dimmed background read as classic SNES modal screens.

---

## 21. Object overlays — wave / difficulty / mod variants

The whole `obj` layer of a map (spawns, doors, NPCs, loot, traps, enemies) can live in a **separate file** loaded after the base map. One terrain JSON, N variant JSONs. Lets you ship:

- **Difficulty modes** — `level1.easy.objects.json`, `level1.hard.objects.json`, `level1.nightmare.objects.json`. Same playfield, different enemy population.
- **Wave-based shooters** (Galaxian / Galaga / Space Invaders style) — fixed playfield, 30 wave files: `wave_001.objects.json` through `wave_030.objects.json`. Each wave is a 30-line file with the formation in JSON.
- **Mods / community content** — drop a third-party `.objects.json` into a folder, game picks it up.
- **Procedural runs** — `OBJSAVE` a generated formation at runtime so the next room reuses it; or persist it for replays.

### `OBJLOAD path$ [, mode$]`

- **Purpose**: load an objects-overlay file into the `MAP_OBJ_*` arrays.
- **Parameters**:
  - `path$` — overlay file path.
  - `mode$` — `"replace"` (default — clears `MAP_OBJ_COUNT` to 0 first) or `"append"` (stacks on top of whatever's already loaded).
- **Returns**: nothing. Updates `MAP_OBJ_COUNT`.

### `OBJSAVE path$`

- **Purpose**: write the current `MAP_OBJ_*` arrays as a Shape A overlay JSON.
- **Parameters**: `path$`.
- **Returns**: nothing. `props` not preserved in this build.

### Overlay schema (Shape A)

```json
{
  "format": 1,
  "kind": "objects-overlay",
  "appliesTo": "level1-overworld",
  "mode": "replace",
  "objects": [
    { "id": 100, "type": "enemy", "kind": "octorok",
      "shape": "rect", "x": 64, "y": 64, "w": 16, "h": 16,
      "props": { "hp": 1, "ai": "wander" } }
  ]
}
```

`appliesTo` is informational — the runtime accepts any overlay so a mismatch becomes the program's responsibility to detect (e.g. compare against `MAP_TILESET_ID$`). Shape B (full map JSON with only the `obj` layer populated) is also accepted as a fallback for editors that emit the wider schema.

### Loading flow — RPG (difficulty)

```basic
MAPLOAD "level1.json"                ' base terrain + maybe a default obj layer

IF DIFF$ = "hard" THEN
  OBJLOAD "level1.hard.objects.json"  ' replace default obj with hard variant
ELSE IF DIFF$ = "easy" THEN
  OBJLOAD "level1.easy.objects.json"
END IF
' If DIFF$ falls through, the base map's default obj layer stays as-is.
```

### Loading flow — shooter (waves)

```basic
MAPLOAD "playfield.json"              ' starfield + boundary tiles

WAVE = 1
DO
  PATH$ = "wave_" + RIGHT$("000" + STR$(WAVE), 3) + ".objects.json"
  IF FILEEXISTS(PATH$) THEN
    OBJLOAD PATH$
    PlayWave()                        ' runs until ENEMY_COUNT = 0
    WAVE = WAVE + 1
  ELSE
    EXIT                              ' no more waves — game won
  END IF
LOOP
```

Each `wave_NNN.objects.json` defines the formation:

```json
{
  "format": 1,
  "kind": "objects-overlay",
  "objects": [
    { "id": 1, "type": "enemy", "kind": "drone",
      "shape": "rect", "x":  16, "y": 16, "w": 16, "h": 16 },
    { "id": 2, "type": "enemy", "kind": "drone",
      "shape": "rect", "x":  48, "y": 16, "w": 16, "h": 16 }
    /* ... 8-30 entries laid out in a grid ... */
  ]
}
```

Designer hand-authors the formation in any text editor; programmer wires the loader. Shipping a new wave = adding one file.

### Stacking overlays — `mode: "append"`

```basic
MAPLOAD "level1.json"
OBJLOAD "level1.npcs.json"               ' base NPCs + doors
OBJLOAD "level1.loot.greedy.json", "append"  ' extra chests + coins
OBJLOAD "level1.enemies.hard.json", "append" ' extra enemies on top
```

Three concerns, three files, one run-time composition. Each overlay can be edited / re-balanced independently. Caller is responsible for picking unique `id` ranges across overlays so no collisions (e.g. `1-99` for NPCs, `100-199` for loot, `200-299` for enemies).

### Using the editor

The same `MAP_OBJ_*` arrays the engine reads are the ones the editor mutates. Workflow when object editing lands in `map_editor.bas`:

1. `MAPLOAD "playfield.json"` — load base.
2. `OBJLOAD "wave_005.objects.json"` — load the variant being edited (or start blank).
3. Editor places / moves / deletes objects → `MAP_OBJ_*` arrays + `MAP_OBJ_COUNT` mutate.
4. `OBJSAVE "wave_005.objects.json"` → file written. Browser: pair with `DOWNLOAD` for a real file.

Tile edits → `MAPSAVE`. Object edits → `OBJSAVE`. Two surgical commands, no schema collision.

### Why this beats one big file

| | One big map.json | Base + overlay files |
|---|---|---|
| Difficulty modes | One obj layer — variants need fork+merge | Native — one file per mode |
| Wave shooter | 30 maps with same tile data | 1 playfield + 30 tiny overlays |
| Mod-ability | Replace whole map | Drop in one overlay |
| Diff in git | Tile churn drowns spawn changes | Clean per-concern diffs |
| Editor save | Rewrite whole JSON | Touch one file |
| Composition | Not possible | `append` mode stacks overlays |

---

## See also

- [level-authoring](https://docs.retrogamecoders.com/basic/rgc-basic/level-authoring/) — `MAPLOAD` vs BASIC builder, migration path.
- [Graphics docs](https://docs.retrogamecoders.com/basic/rgc-basic/graphics-raylib/) — sprites, screen modes, `OVERLAY` HUD plane.
- [Language reference](https://docs.retrogamecoders.com/basic/rgc-basic/language/) — `MAPLOAD` / `MAPSAVE` reference.
- [Network & buffers](https://docs.retrogamecoders.com/basic/rgc-basic/network-and-buffers/) — load `.json` levels over HTTP for hot-reload during play-testing.
- [Map format spec (in repo)](https://github.com/omiq/rgc-basic/blob/main/docs/map-format.md) — JSON schema, decision log, v1.1+ deferrals.
- [Overlay plane (in repo)](https://github.com/omiq/rgc-basic/blob/main/docs/overlay-plane.md) — HUD plane (life bar, dialog box) above the world.
- [`examples/rpg/rpg.bas`](https://github.com/omiq/rgc-basic/blob/main/examples/rpg/rpg.bas) — production engine for chapters 1-2 ([open in IDE](https://ide.retrogamecoders.com/?file=rpg/rpg.bas&platform=rgc-basic)).
- [`examples/rpg/level1_overworld.json`](https://github.com/omiq/rgc-basic/blob/main/examples/rpg/level1_overworld.json) — canonical example of `obj` layer with spawn + door + npc.
