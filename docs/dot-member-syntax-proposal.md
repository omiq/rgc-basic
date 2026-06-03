# Proposal: `.` member-access syntax for dict values

**Status:** Proposal / parked. Not scheduled. Captured so the idea isn't
re-derived from scratch each time the dict-as-struct pattern gets verbose.

**Origin:** Fell out of the `trek-new.bas` entity-model refactor
(`docs/trek-refactor-next-steps.md`, Phase A). The entity model lives in a
single dict keyed by id; every field read/write is a `DICTGETN` /
`DICTSET` call with a dotted **string** path. That works, but the call-based
form is noisy in hot code (AI loops, combat resolution).

## TL;DR

Add optional sugar so a dict handle in a variable can be read and written
with `.` member access:

```basic
HP = SHIP.hull            ' sugar for  HP = DICTGETN(SHIP, "hull")
SHIP.hull = HP - 20       ' sugar for  DICTSET SHIP, "hull", HP - 20
X = SHIP.pos.x            ' sugar for  DICTGETN(SHIP, "pos.x")
```

The dict runtime already supports everything this needs (nested
object/array nodes, dotted-path walk, auto-vivify on write). **This is a
parser/desugaring feature, not a runtime feature.** No new node kinds, no
storage change.

## Why this is *not* Phase A

Phase A ships on the interpreter as it stands today. The string-path API is
fully sufficient to build the galaxy/entity model:

```basic
DICTSET GAME, "ent." + ID$ + ".hp", 200
HP = DICTGETN(GAME, "ent." + ID$ + ".hp")
```

Dot syntax is pure ergonomics on top of that. It touches the **expression
grammar**, which is the riskiest part of the language to extend (every
existing program is a test case). Bundling it into a game-refactor episode
would conflate "new game data model" with "new language surface" and put
the regression corpus at risk for a convenience win. Keep them separate.

## Desired surface

| Form | Desugars to |
|------|-------------|
| `expr.key` (rvalue) | `DICTGETN(expr, "key")` |
| `expr.k1.k2` (rvalue) | `DICTGETN(expr, "k1.k2")` |
| `lhs.key = rhs` | `DICTSET lhs, "key", rhs` |
| `lhs.k1.k2 = rhs` | `DICTSET lhs, "k1.k2", rhs` |

Where `expr`/`lhs` evaluates to a dict handle (a number, by current
convention). Type at runtime is dynamic; if the handle isn't a dict the
existing `DICTGETN`/`DICTSET` fail-soft behaviour applies (default value /
`json_last_status`).

Out of scope for a first cut (keep the bracket forms as-is):

- Array indexing `ship.guns[2]` — still `DICTGETN(SHIP, "guns[2]")`.
  Mixing `.` and `[]` in the parser is the hard part; defer.
- Computed keys `ship.(k$)` — use the string API.
- Method-call illusion / any behaviour. This is data access only.

## Implementation sketch (needs verification before any work)

The two hook points, both in the expression/statement layer of `basic.c`:

1. **Rvalue.** Wherever a primary that resolved to a numeric variable is
   followed by `.` + identifier, fold into a `DICTGETN` call with the
   accumulated dotted key. This is a *postfix* parse step after the
   primary, looping while the next char is `.` and the following token is a
   bare identifier (not a number — `3.14` must still parse as a float).
2. **Lvalue.** The assignment statement parser, when it sees
   `ident . ident [ . ident ]* =`, emits a `DICTSET` instead of a scalar
   store.

### Edge cases / landmines

- **Float literals.** `A = 3.14` and `X = N.5`-style inputs must not be
  read as member access. The `.` is only member access when the **left**
  side is an identifier/handle expression and the **right** side is a bare
  identifier (alpha-leading), never a digit. Get this wrong and you break
  every program with a decimal.
- **`PRINT A.B`** and `.` inside strings — string contents are untouched
  (lexer already isolates string literals), but confirm.
- **Existing programs using `.` in variable names.** ✅ **Checked, clear.**
  `is_ident_char` (`basic.c:954`) = `isalpha | isdigit | $ | _` — `.` is
  **not** a valid identifier char today, so no program can have a dotted
  variable name. The `.` token is free to claim for member access without a
  flag or breaking change. (This was the gating question; it's answered.)
- **Keyword/reserved-word keys.** `ship.type` — `type` may collide with a
  reserved word. The string-path form has no such issue. The sugar needs to
  treat the post-`.` identifier as a key literal, not a token to reserve.
- **Auto-vivify on write** already works via `DICTSET` (it creates missing
  intermediates). `SHIP.a.b.c = 1` should Just Work through desugaring —
  verify against `dict_walk_for_write(..., create=1)`.

## Cost / value

- **Value:** readability in entity/AI code; lowers the barrier for tutorial
  readers who expect `e.hp`. Aligns with the "dicts as objects" pull case
  already accepted in `docs/map-type-proposal.md`.
- **Cost:** medium-high *risk*, low-medium *effort*. The code is small; the
  exposure is the whole expression grammar. Needs the float-literal and
  `.`-in-identifier questions answered first, plus a dedicated regression
  pass (existing `.bas` corpus must produce identical output).

## Recommendation

Park until the entity model has shipped through at least Phase B and the
string-path verbosity is felt in real code, not anticipated. If/when picked
up:

1. Gating question already answered (`.` not an identifier char,
   `basic.c:954`). The remaining live risk is the float-literal
   disambiguation in the expression parser.
2. Spike rvalue read only (`SHIP.hull` → `DICTGETN`), behind no flag, run
   the full example/regression corpus, diff output.
3. Add lvalue write only if read lands clean.
4. Leave `[]` indexing and computed keys on the string API indefinitely.

## References

- Dict runtime: `basic.c` — `DICTGETN`/`DICTSET`/`DICTKEY$`, `dict_node`,
  `dict_walk_for_write` (auto-vivify).
- Accepted dict-as-struct case: `docs/map-type-proposal.md`.
- Consumer that motivated this: `docs/trek-refactor-next-steps.md` Phase A.
