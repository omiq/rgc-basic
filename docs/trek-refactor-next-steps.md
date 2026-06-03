# Trek-new refactor: next steps

Design notes for the `examples/trek-new.bas` tutorial series. The goal is not to preserve every 1974 Trek detail forever, but to grow a **text-based space sandbox** that can become a BBS/telnet game, with Trek as the first scenario.

**Keep on purpose**

- Text commands (`NAV`, `SRS`, `COM`, …) and terminal-style output (ANSI/PETSCII today, plain telnet later).
- Deterministic regression (`tests/trek_new_regression.sh`) as each refactor lands.

**Retire or replace over time**

- Packed numeric galaxy cells `G(8,8)` and mirror `Z(8,8)`.
- String-only quadrant as the *authoritative* model (strings remain fine for **display** and save files).
- Global scratch variables (`K3`, `X1`, `D0`, …) and hidden coupling (`def FND` using loop index `I`).

---

## Destination (tutorial north star)

### 1. Real galaxy matrix (ships can move)

Move from `G(qx,qy) = klingons*100 + bases*10 + stars` to structured data:

- **Galaxy level:** fixed grid (e.g. 8×8 quadrants), each cell holding faction presence, hazards, or a pointer into detail.
- **Quadrant level:** sector grid (e.g. 8×8 sectors), each sector holding zero or more **entities** (ships, stations, asteroids, …).
- **Entities** have type, faction, position, velocity or course, HP, cargo, hostility, aggression, and optional AI state.

Player movement updates one entity; NPC movement updates others in the same quadrant (and eventually across quadrant boundaries). `THIS_QUADRANT$` becomes a **view** built from the matrix (for SRS and saves), not the source of truth.

### 2. Richer actors than Enterprise vs Klingons

- Ship **classes** (scout, trader, pirate, military, …).
- **Hostility** (neutral, hostile, allied) and **aggression** (fight, flee, trade, ignore unless provoked).
- Example: pirates hostile but **reactive** (fire only if fired upon; otherwise run).

### 3. Fleets, not just three Klingon slots

Replace `K(3,3)` and `K3` counts with a **fleet list** per quadrant (or per faction in quadrant):

- Formation, orders, reinforcement from adjacent quadrants.
- Trek “three cruisers” is one fleet instance with `ship_count` or three linked ships.

### 4. Bases and ownership

- Starbases (and ports) with **owner faction** (Federation, neutral, pirate, …).
- Docking, repair, and trade depend on faction + reputation, not a single `D0` docked flag.

### 5. Non-combat tactics

Commands and state beyond NAV/PHA/TOR:

- **Trade** (cargo, prices, contraband).
- **Construction** (stations, mines, defences).
- **Mining** (resource extraction, depleted sectors).

Combat remains; economy and construction drive long-term goals.

### 6. Later: multiplayer (optional)

Only after single-player is stable:

- **Saved seed** for reproducible solo runs (already aligned with regression harness).
- Shared galaxy state, turn or tick sync, command queue per player.
- Host layer (telnet/BBS) separate from simulation rules.

---

## What trek-new already has (baseline)

| Area | Status |
|------|--------|
| Main loop | `ST_*` state machine, no inter-routine `GOTO`/`GOSUB` |
| Commands | `CMD_DICT` + `SELECT CASE` dispatch |
| Quadrant display | `THIS_QUADRANT$`, `PlaceToken`, `CheckSector`, `SectorIndex` |
| Devices | `DEVICE_DAMAGE(8)`, `DEVICE_NAME$(8)` |
| Loops | `EXIT FOR` / `CONTINUE` in warp, combat, damage, scans |
| Input | `Ask$`, `AskNumber` (BBS-friendly) |
| Names | `QuadrantName$`, `InitCommandDict` |
| Tests | `trek_new_regression.sh` scenarios A/B/C |

---

## Technical debt to clear (pre-matrix)

Small, safe cleanups that do not change game design. Do these in tutorial-sized PRs so each episode stays reviewable.

1. **Device constants** — `DEV_WARP=1`, … alongside `DEVICE_NAME$`; replace magic numbers in `if DEVICE_DAMAGE(4)`.
2. **`DistanceToKlingon(i)`** — replace `def FND(D)` and `FND(0)` in phaser loop.
3. **`SyncGalaxyCell(qx, qy)`** — one place that writes `G` and `Z` after kills/torpedoes.
4. **Computer menu** — second dict or `SELECT CASE` on string keys; drop `A`/`A1`/`H8`/`COMFLAG` where possible.
5. **I/O boundary** — group `GetInput`, `Pause`, colour globals (`InitColours`, `{CYAN}` helpers) behind names like `HostPrint`, `HostReadLine` (can stay thin wrappers in the same file at first).
6. **Interpreter** — drop `QN$` assign-before-`PRINT` once full-program inline `QuadrantName$` is verified (see `to-do.md` UDF/PRINT note).
7. **Break mega-lines** — especially Nav warp and torpedo track; behaviour unchanged, goldens unchanged.

---

## Phased roadmap

### Phase A — Data model sketch (tutorial: “galaxy as a dictionary”)

**Goal:** Introduce the dict-backed entity model alongside Trek behaviour, without deleting the legacy `G`/`Z`/`K()` arrays yet.

**Decided storage model: a few top-level dicts split by type, each keyed by id; entities are tombstoned (status), never deleted, during play.** Verified against the interpreter (`basic.c`), not assumed:

- `MAX_DICTS` (`basic.c:2284`) caps *top-level dict handles* (slots) at 128. It does **not** cap children. Each `DICTNEW()` slot holds an unbounded nested tree (objects/arrays grow by `cap`). Dict-per-entity (`DICTNEW()` in a loop) would burn the slot cap and is the wrong shape. The opposite extreme (one mega-dict for everything) works but bloats every path string and forces a type filter on every iteration.
- **Middle ground: one handle per entity *type* (plus one for factions).** A fixed, tiny handle set — `SHIPS`, `BASES`, `STARS`, `PLAYER`, `GALAXY`, `FACTIONS` — plus the existing `CMD_DICT`. ~7 handles, set up once at boot, never grows with entity count. Trivially inside 128 with room for later types (`MINES`, `STATIONS`, …). Each type-dict is an object keyed by monotonic id; entity count is bounded only by memory.
- The array-dimension limit (`MAX_DIMS 3`, `basic.c:1968`) is real but irrelevant here — dicts sidestep it entirely.
- **Kill == mark status, not delete.** A destroyed ship gets `status = ST_DESTROYED`; its key stays. This sidesteps the array-reindex hazard entirely (`DICTDEL` on an array splices + shifts via `dict_arr_del`, `basic.c:11091`, rotting positional ids — but we never delete during play, so it cannot bite). It also keeps the *record*: defeated count = count of `ST_DESTROYED`, and the score screen / post-mortem get data, not just a number. Use a **status enum, not a bool** — `ST_ALIVE` / `ST_DESTROYED` / `ST_FLED` / `ST_DOCKED` — because Phase C pirates *flee*, which is not the same event as *killed* and must be distinguishable.
- **Objects, not JSON arrays, within each type-dict.** Even with tombstoning, object-key storage makes the eventual compaction sweep trivial (rebuild the dict copying only live entities; survivors keep their ids within the session). Arrays would force a positional rebuild.

Why split by type beats one mega-dict:

- **Iterate one type with no filter** — `UpdateShips` walks `SHIPS` only; it never sees stars or bases.
- **Shorter paths** — `DICTGETN(SHIPS, ID$ + ".hp")` not `DICTGETN(GAME, "ships." + ID$ + ".hp")`.
- **Pass one type to a function** — `ResolveCombat(SHIPS)` instead of threading a sub-path.
- **Per-type lifecycle** — regenerate a quadrant's stars with `DICTFREE STARS : STARS = DICTNEW()`; ships and the player survive untouched.

**Slot budget:** ~7 named handles, fixed at boot, vs a cap of 128. Headroom is a non-issue.

**Faction is data, not a constant.** Each entity's `fac` is the **string key** into `FACTIONS` (`"klingon"`), so `DICTGETN(FACTIONS, ENT_FAC$ + ".aggression")` works with no constant↔key mapping table. The old `FAC_*` integer constants are dropped. In Phase A `FACTIONS` carries only identity/display/victory fields (`name`, `token`, `colour`, live `count`); behaviour fields (`rel` faction-vs-faction relations, `aggression`, `reputation`) land in Phase C, after Phase B proves movement. Reserve the shape now; don't model the AI table yet.

Concrete shape:

```basic
' --- status enum (tombstone, not delete) ---
ST_ALIVE=0 : ST_DESTROYED=1 : ST_FLED=2 : ST_DOCKED=3

' --- type dicts: one handle each, allocated once at boot ---
SHIPS    = DICTNEW()            ' mobile actors (incl. Klingons), keyed by id
BASES    = DICTNEW()            ' starbases / ports, keyed by id
STARS    = DICTNEW()            ' stars, keyed by id
PLAYER   = DICTNEW()            ' the Enterprise (singleton: fields at root)
GALAXY   = DICTNEW()            ' quadrant-level summary for LRS / map
FACTIONS = DICTNEW()            ' faction records, keyed by faction name
NextId   = 0                    ' monotonic id source, shared across types; never reused

' --- faction setup (Phase A: identity + victory count only) ---
DICTSET FACTIONS, "klingon.name",   "Klingon"
DICTSET FACTIONS, "klingon.token",  "K"
DICTSET FACTIONS, "klingon.colour", RED
DICTSET FACTIONS, "klingon.count",  0     ' bumped per spawn, dropped per kill

' --- spawn into a given type dict (returns the new id as a string key) ---
function SpawnInto$(TYPEDICT, FAC$, QX, QY, SX, SY, HP)
  ID$ = "e" + STR$(NextId) : NextId = NextId + 1
  P$ = ID$ + "."
  DICTSET TYPEDICT, P$ + "fac",    FAC$          ' string key into FACTIONS
  DICTSET TYPEDICT, P$ + "status", ST_ALIVE
  DICTSET TYPEDICT, P$ + "qx",     QX
  DICTSET TYPEDICT, P$ + "qy",     QY
  DICTSET TYPEDICT, P$ + "sx",     SX
  DICTSET TYPEDICT, P$ + "sy",     SY
  DICTSET TYPEDICT, P$ + "hp",     HP
  DICTSET FACTIONS, FAC$ + ".count", DICTGETN(FACTIONS, FAC$ + ".count") + 1
  SpawnInto$ = ID$
end function
```

The id source is shared across type-dicts so an id is globally unique — a cross-reference can carry `(typedict, id$)` without ambiguity (relevant once ships target each other in Phase B/C).

**Iterate one type** via `DICTKEY$` (enumerates object keys in insertion order, `basic.c:13833`), skipping the dead:

```basic
N = DICTLEN(SHIPS, "")          ' "" path = the dict root object
FOR I = 0 TO N-1
  ID$ = DICTKEY$(SHIPS, "", I)
  IF DICTGETN(SHIPS, ID$ + ".status") <> ST_ALIVE THEN CONTINUE
  IF DICTGETN(SHIPS, ID$ + ".qx") = QUAD_X THEN ...
NEXT
```

**Kill = tombstone** (key persists; denormalised faction count decremented for an O(1) victory test):

```basic
function KillShip(ID$)
  DICTSET SHIPS, ID$ + ".status", ST_DESTROYED
  FAC$ = DICTGET$(SHIPS, ID$ + ".fac")
  DICTSET FACTIONS, FAC$ + ".count", DICTGETN(FACTIONS, FAC$ + ".count") - 1
end function

' victory: O(1), no scan
IF DICTGETN(FACTIONS, "klingon.count") = 0 THEN GameState = ST_VICTORY
' end-of-game breakdown: scan statuses for "you destroyed N"
```

**Tombstones never reclaim — sweep at boundaries (deferred).** Every ship ever spawned lingers. Fine at Trek scale (tens of entities, one mission). For the long-running BBS sandbox (Phase F/G) add a **compaction sweep** at safe points (quadrant regen, save/load) that rebuilds each type-dict copying only `ST_ALIVE` entities. Object-key storage makes this a straight copy-the-living loop. Noted now, built when Phase F/G needs it (see Tests/roadmap).

**Arrays stay legal — but only for transient, reference-free lists** (e.g. torpedoes in flight this turn). Anything another entity points at, or anything that needs a stable id across its lifetime, lives in a type-dict keyed by id.

**Bridge to the view:** `BuildQuadrantString()` fills `THIS_QUADRANT$` by walking each type-dict, taking only `status = ST_ALIVE` entities whose `qx`/`qy` = current quadrant, placing each at `sx,sy` using its faction `token`/`colour`. `PlaceToken` becomes `SetEntityAt(...)` writing the entity then rebuilding the view. `THIS_QUADRANT$` is now a derived view, not the source of truth.

**Keep legacy in sync during transition:** after every entity mutation, mirror into `G`/`Z`/`K()` (`SyncGalaxyCell`, debt item #3) so LRS and the computer keep working until later phases retire them.

**Regression:** existing `trek_new_regression.sh` must stay green after each step. Add an assertion that `BuildQuadrantString()` output equals the legacy `THIS_QUADRANT$` byte-for-byte during transition — that proves the dict→view rebuild is faithful.

**Demo idea:** same SRS output, but log “entity moved” when a test Klingon advances one sector.

> **Note on `entity.field` ergonomics.** The dotted path lives *inside the string* (`DICTGETN(GAME,"ent.e3.hp")`); there is no native `entity.hp` member operator. Adding one is a parser-level feature, out of scope for Phase A. See `docs/dot-member-syntax-proposal.md`.

### Phase B — NPC movement (tutorial: “they move when you move”)

**Goal:** Prove the matrix model.

- After player warp or end-of-turn tick: `UpdateQuadrantAI()` moves non-player ships in current quadrant.
- Start with one behaviour: Klingon drifts toward Enterprise or random empty sector.
- Replace `KlingonsMove:` loop body with iterate-entity-list.
- Remove dependence on `K(3,3)` for position (keep HP on entity).

### Phase C — Factions and behaviour flags (tutorial: “pirates that run”)

**Goal:** Hostility + aggression drive AI, not hard-coded “Klingon always fires”.

- Fields: `Hostility`, `Aggression`, `Morale` (optional).
- AI table or `SELECT CASE` on `(faction, aggression)` → flee / hold / pursue / trade.
- `KlingonsFire` → `ResolveCombatRound()` for entities that chose to attack.
- Neutral bases: dock only if `Hostility <= NEUTRAL` and reputation OK.

### Phase D — Fleets (tutorial: “task force in quadrant 4,2”)

**Goal:** Multiple ships as one logical fleet plus escorts.

- Fleet id, leader sector, member list or `ship_count` with spread sectors.
- LRS/galactic map shows aggregated strength (e.g. three digits still, meaning “total hull” or “ship count”).
- Combat: damage distributed or flagship rules.

### Phase E — Economy and commands (tutorial: trade / mine / build)

**Goal:** New command verbs (or `COM` subcommands) wired to state.

- Cargo hold on player ship; station inventories per faction.
- Commands: `TRD`, `MINE`, `BUILD` (names TBD) via dict like `CMD_DICT`.
- Stardate/cost loops reuse existing time advance.

### Phase F — Single-player meta (tutorial: seed and restart)

**Goal:** Roguelike-style replay.

- Persist `GameSeed` at `SetupGame`; all `rnd` driven from seed (regression already uses fixed `rnd(1)` in harness).
- Optional `SAVE`/`LOAD` of galaxy matrix + entities (JSON via existing dict/HTTP patterns, or custom binary in `BUFFER`).

### Phase G — Multiplayer (research spike only)

**Goal:** Document constraints, no implementation until F is fun.

- Authoritative server vs host-turn BBS door.
- Command text lines as protocol (`NAV 4 2` …).
- What must leave `trek-new.bas` and live in a shared “engine” module (still BASIC for the series, or C host later).

---

## Suggested file / module layout (when the file gets too large)

Stay in one `.bas` for tutorials until pain is obvious, then split by **include** or copy-paste chapters:

| Module | Responsibility |
|--------|----------------|
| `trek-host.bas` | `Ask$`, `Pause`, colours, box drawing, command prompt |
| `trek-galaxy.bas` | Pack/unpack, matrix, LRS neighbour read |
| `trek-entities.bas` | Spawn, move, token view, collision |
| `trek-ai.bas` | Faction behaviours, combat initiation |
| `trek-commands.bas` | `DoCommand`, Nav, Phasers, … |
| `trek-game.bas` | State machine, setup, victory/defeat |

Names are illustrative; the series can introduce one file per episode.

---

## Mapping old variables (cheat sheet for refactors)

| Legacy | Likely replacement |
|--------|-------------------|
| `G(qx,qy)`, `Z(qx,qy)` | `GalaxyCell` record or parallel arrays |
| `K3`, `B3`, `S3` | Count entities by type in quadrant |
| `K(i,1..3)`, `K(i,3)` hp | `ent.<id>` fields (`sx`,`sy`,`hp`) in the `GAME` dict |
| `THIS_QUADRANT$` | `RenderQuadrantView()` |
| `PlaceToken` | `SetEntity` + rebuild view |
| `CheckSector` | `EntityAt(sx,sy)` |
| `D0` docked | `PlayerDockedAt` + faction check |
| `ATAKFLAG`, `SRSFLAG` | Event flags or turn phase enum |
| `def FND` | `Distance(ex1,ey1,ex2,ey2)` |
| `def FNR` | `RandomSector()` or `RndRange(1,8)` |

---

## Tests to add as phases land

| Test | When |
|------|------|
| `trek_entity_move.bas` | After Phase B: one NPC moves deterministically |
| `trek_pirate_flee.bas` | After Phase C: pirate aggression = flee when damaged |
| `trek_fleet_count.bas` | After Phase D: fleet strength on LRS matches entities |
| `trek_trade_smoke.bas` | After Phase E: buy/sell changes cargo and credits |
| Extend `trek_new_regression.sh` | Only when output is intentionally unchanged; new scenarios for new behaviour |

---

## References in this repo

- Example: `examples/trek-new.bas`
- Regression: `tests/trek_new_regression.sh`, `tests/fixtures/trek_new/`
- Interpreter UDF/PRINT fix: `CHANGELOG.md` (2026-06-02), `tests/udf_print_inline_next.bas`
- Follow-up: `to-do.md` (Engineering → UDF inside PRINT / trek `QN$` workaround)
- Language features used: `docs/rgc-basic-llm-guide.md`, `FUNCTION`, `SELECT CASE`, dicts, `EXIT FOR`

---

## Open decisions (pick as tutorials go)

1. **Grid sizes:** stay 8×8 galaxy / 8×8 sector for familiarity, or resize early?
2. ~~**Max entities per sector:** fixed array vs dynamic list.~~ **Decided (Phase A):** one container dict `GAME`, entities as an object keyed by monotonic id (`ent.e0`, `ent.e1`, …). Dict children are uncapped; only top-level handles hit `MAX_DICTS`. Object keys give stable identity under delete; arrays reindex on `DICTDEL`.
3. **Turn model:** continuous time (stardate += warp factor) vs explicit turns for multiplayer.
4. **Faction count:** start with Fed / Klingon / Neutral, add pirates in Phase C.
5. **Public docs:** when galaxy matrix is user-visible, add a retrodocs page under `retrodocs` (same change-set rule as language features).

---

*Last updated: 2026-06-02. Revise this doc when a phase ships or the north star changes.*
