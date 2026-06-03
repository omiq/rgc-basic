# Proposal: `.` member-access syntax for dict values

**Status:** Candidate general language feature. Not yet scheduled, but
promoted from "parked trek sugar" — the value is language-wide, not
trek-specific (see *Cost / value*). Its own work item with its own
regression sweep; never bundled into a trek episode.

**Origin:** Fell out of the `trek-new.bas` entity-model refactor
(`docs/trek-refactor-next-steps.md`, Phase A). The entity model lives in
type-dicts keyed by id; every field read/write is a `DICTGETN` / `DICTSET`
call with a dotted **string** path. That works, but the call-based form is
noisy in hot code (AI loops, combat resolution). The general case — *any*
rgc-basic program that wants struct-shaped data without struct/OOP
machinery — is the real motivation; trek is just the first consumer.

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

- **Value (general, not trek):** this is the cheapest way to give rgc-basic
  struct-shaped ergonomics without adding a struct/record/OOP type system.
  It is the "dicts as objects" pattern every dynamic language leaned on
  before formal records (Perl, Lua, JS, Python pre-dataclass). For a retro
  teaching language it directly lowers the "this reads like 1980s BASIC"
  barrier: `ship.hp = ship.hp - 20` looks like every modern language. Any
  program modelling entities, config, parsed JSON, or game state benefits;
  trek is just the first consumer. Aligns with the "dicts as struct
  substitute" pull case already accepted in `docs/map-type-proposal.md`.
- **Cost:** medium-high *risk*, low-medium *effort*. The code is small; the
  exposure is the whole expression grammar. Needs the float-literal
  question handled (the `.`-in-identifier gating question is already
  answered, below), plus a dedicated regression pass (existing `.bas` corpus
  must produce identical output).

### It is struct *aesthetics*, not struct *safety* — be honest about that

The sugar makes a hashmap *look* like a record. It does not make it *behave*
like one, and that gap is a teaching trap if undocumented:

- **No field checking.** `DICTGETN` is fail-soft — a typo `ship.hl` silently
  reads the default (0/""), no error. A real struct catches that at compile.
  The reader thinks they have a struct; they have a hashmap with nicer
  syntax.
- **Mitigation — optional strict-field mode.** An opt-in (`#OPTION
  STRICTFIELDS`, following the `#OPTION beats CLI beats default` precedence
  rule) where reading an absent key *errors* instead of returning the
  default. Opt-in so the fail-soft default everyone else relies on is
  unchanged. This is what elevates the feature from sugar to something worth
  marketing — "structs when you want them, hashmaps when you don't" — but it
  is a follow-up, not part of the first cut.

### Reference semantics — the "looks like value, acts like reference" trap

A dict handle is a type-erased integer (`DICTNEW()` returns a number). So
`a = ship` copies the **handle**, not the dict — `a.hp = 0` mutates the same
underlying dict. OOP-trained users expect that; BASIC-trained users expect a
value copy. The dot syntax sharpens the trap because `a.hp` *looks* like
member access on an object.

The crux: the language cannot tell `a = ship` (handle) from `a = score`
(plain number) at assignment time, because both are just numbers. That rules
out the obvious fix and shapes the menu:

| Option | Cost | Notes |
|--------|------|-------|
| **Reference default + document loudly** | zero | Matches Py/JS/Lua; the `.` signals objectness. Footgun remains. |
| Auto value-copy on `=` | — | **Impossible** while handles are ints (can't distinguish handle-assign from number-assign). Needs the value-type option below. |
| **`DICTCLONE(h)` builtin, reference stays default** | low | Teaches "alias by default, clone when you mean copy" (Python's `.copy()`). |
| Promote MAP to a first-class value type with copy-on-write | high | Lets `=` *define* value semantics cheaply. The "proper" fix. |
| Type sigil for handles (`ship~`) | medium | BASIC-idiomatic visibility (`$` for strings); add only if users actually trip. |

**Clustering insight:** every *clean* answer (auto-copy, COW value
semantics) requires promoting MAP to a distinct value type — and that is the
*same* investment that unlocks strict-field safety and real type errors. So
the decision is one fork, not three:

- **Cheap track (recommended now):** handles stay ints → reference semantics
  + `DICTCLONE` + loud docs + optional `STRICTFIELDS`. Footgun *managed*,
  not removed.
- **Proper track (someday):** MAP becomes a first-class value type → value
  semantics *and* strict fields *and* real errors in one investment. Big
  lift; do it whole or not at all. Don't half-build a value type.

## Recommendation

Treat as a **candidate general language feature** on the cheap track:
reference semantics, `DICTCLONE` for explicit copies, loud docs on aliasing,
and an optional `STRICTFIELDS` mode as a follow-up. Do **not** half-build a
MAP value type; that is the proper-track investment and is whole-or-nothing.

Sequencing when picked up (still independent of any trek episode — trek runs
fine on the string-path API regardless):

1. Gating question already answered (`.` not an identifier char,
   `basic.c:954`). The remaining live risk is the float-literal
   disambiguation in the expression parser.
2. Spike **rvalue read only** (`SHIP.hull` → `DICTGETN`), behind no flag, run
   the full example/regression corpus, diff output. This is the make-or-break
   step for the float-literal question.
3. Add **lvalue write** only if read lands clean.
4. Ship `DICTCLONE` alongside, and document reference semantics in the same
   change-set (it becomes user-visible the moment dot syntax exists).
5. `STRICTFIELDS` and the whole MAP-value-type question are **separate**
   follow-ups, decided on their own merits.
6. Leave `[]` indexing and computed keys on the string API indefinitely.

When this ships, it is a public-facing language feature → update
`retrodocs/docs/basic/rgc-basic/language.md` in the same change-set (the
CLAUDE.md public-docs rule), including the aesthetics-not-safety and
reference-semantics caveats so external adopters aren't surprised.

## References

- Dict runtime: `basic.c` — `DICTGETN`/`DICTSET`/`DICTKEY$`, `dict_node`,
  `dict_walk_for_write` (auto-vivify).
- Accepted dict-as-struct case: `docs/map-type-proposal.md`.
- Consumer that motivated this: `docs/trek-refactor-next-steps.md` Phase A.
