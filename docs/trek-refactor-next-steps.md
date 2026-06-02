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

### Phase A — Data model sketch (tutorial: “galaxy as tables”)

**Goal:** Introduce parallel structures without deleting Trek behaviour yet.

- Add typed constants: `ENTITY_EMPTY`, `ENTITY_SHIP`, `ENTITY_BASE`, `ENTITY_STAR`, factions `FAC_FED`, `FAC_KLINGON`, `FAC_NEUTRAL`, …
- `dim GalaxyQuadrant(8,8)` or separate arrays: `GalaxyKlingons(8,8)`, `GalaxyBases(8,8)`, … OR one record per cell if the language gains a struct story (until then, parallel arrays are fine).
- **Quadrant entities:** `dim SectorEntityType(8,8, MAX_ENTITIES_PER_SECTOR)` or a flat list with `(sector_x, sector_y, type, faction, hp, …)` and `EntityCount`.
- **Bridge:** `BuildQuadrantString()` fills `THIS_QUADRANT$` from entity list; `PlaceToken` becomes `SetEntityAt(sx, sy, type, faction)` + rebuild view.
- Keep `G`/`Z` in sync via `PackGalaxyCell` / `UnpackGalaxyCell` during transition so LRS/computer still work.

**Regression:** existing `trek_new_regression.sh` must stay green after each step.

**Demo idea:** same SRS output, but log “entity moved” when a test Klingon advances one sector.

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
| `K(i,1..3)`, `K(i,3)` hp | Entity list slot `i` or fleet member |
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
2. **Max entities per sector:** fixed array (simple) vs dynamic list (needs dict or linked structure).
3. **Turn model:** continuous time (stardate += warp factor) vs explicit turns for multiplayer.
4. **Faction count:** start with Fed / Klingon / Neutral, add pirates in Phase C.
5. **Public docs:** when galaxy matrix is user-visible, add a retrodocs page under `retrodocs` (same change-set rule as language features).

---

*Last updated: 2026-06-02. Revise this doc when a phase ships or the north star changes.*
