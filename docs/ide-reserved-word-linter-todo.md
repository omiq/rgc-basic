# IDE reserved-word linter — TODO

Status: **deferred.** Caught us multiple times in `map_editor.bas`:
the parser does keyword-prefix matching (`starts_with_kw` in
`basic.c`), so identifiers that *contain* a reserved word break:

  - `BTN_NEXT_X0` → tokenises as `BTN_` `NEXT` `_X0` (NEXT closes a
    FOR loop)
  - `STEP = 0` → reserved (FOR ... STEP n)
  - `PI`, `VAL`, `END`, `TO`, `FOR`, `IF`, `THEN`, `ELSE`, … all
    forbidden as bare identifiers and as embedded substrings.

Errors only surface at compile time and the message points at the
mangled re-token (`BTN_ NEXT _X0` with spaces inserted), which
isn't obvious for a learner.

## What to build

A pre-build pass in the IDE that scans `.bas` source and underlines
identifiers that hit either the reserved set or contain a reserved
substring at a token boundary.

### Scope

- **Live in:** `8bitworkshop/src/platform/rgcbasic.ts` (or a sibling
  `rgcbasic-lint.ts`).
- **Trigger:** `loadEditor` for `.bas` files, on every dirty edit
  (debounced 300 ms).
- **Output:** CodeMirror `lint` markers — gutter icon + hover
  tooltip. Existing compile-error machinery (`reportRuntimeError` /
  builder error widgets) is reused for the layout if straightforward.

### Reserved-word source of truth

The canonical list lives in `basic.c` around lines 3395..3422 (the
`reserved_words[]` array passed to keyword-detection). Two options:

1. **Bake at build time.** Run a tiny script during
   `scripts/sync-rgc-basic.sh` that greps `reserved_words[]` out of
   the synced `basic.c` and emits
   `src/platform/rgc-basic-reserved.gen.ts` exporting a TS string
   array. Sync stays the single source of truth.
2. **Hard-code in TS.** Copy the list once. Risk: drift when a new
   keyword lands in basic.c. Less work day-zero.

Bake at build time is the right answer once the list stabilises.

### Algorithm

```ts
const RESERVED: Set<string> = ...;     // from gen file

function scanForReserved(src: string): Diagnostic[] {
  const out: Diagnostic[] = [];
  // Strip comments + string literals first so "DON'T BREAK NEXT"
  // inside a PRINT string doesn't fire.
  const stripped = stripCommentsAndStrings(src);
  // Split into tokens — letters/digits/$/_, plus split at _ so
  // BTN_NEXT_X0 -> ['BTN', 'NEXT', 'X0'] and any sub-token can
  // be flagged independently.
  const tokenRe = /([A-Z_][A-Z0-9_]*\$?)/g;
  let m: RegExpExecArray | null;
  while ((m = tokenRe.exec(stripped)) !== null) {
    const ident = m[1];
    const upper = ident.toUpperCase();
    // Whole-identifier collision (covers PI, VAL, STEP, END, …)
    if (RESERVED.has(upper)) {
      out.push({
        from: m.index, to: m.index + ident.length,
        severity: "error",
        message: `'${ident}' is reserved in RGC BASIC. Rename the variable.`,
      });
      continue;
    }
    // Embedded-substring collision — only when split at "_" because
    // that's where the parser's keyword-prefix matcher trips.
    const parts = upper.split("_");
    for (let i = 0; i < parts.length; i++) {
      if (RESERVED.has(parts[i])) {
        out.push({
          from: m.index, to: m.index + ident.length,
          severity: "warning",
          message: `'${ident}' contains the reserved word '${parts[i]}' which the parser may catch as a keyword. Pick another name.`,
        });
        break;
      }
    }
  }
  return out;
}
```

Two-tier (error vs warning) keeps the bare collision scary while
the substring case (which only sometimes breaks) reads as a
heads-up. False positives hurt less than a confusing compile
error five minutes into editing.

### Edge cases

- **String literals.** `PRINT "FOR EACH ITEM"` must not trip. Strip
  contents of `"..."` before scanning.
- **Comments.** Same — strip `^\s*\d*\s*REM\b.*$` and `'...$`.
- **Numeric labels.** `10 LET X = 1` already matched; no false
  positive.
- **CHR$ codes.** `CHR$(34)` — `CHR` isn't reserved as a name; only
  the `$`-suffixed intrinsic is the function. Token regex captures
  `CHR$` whole; reserved set should hold `CHR$` for the intrinsic
  and let bare `CHR` through (which is already a keyword anyway).
- **Function/sub names.** `FUNCTION DrawHud()` — token after
  FUNCTION keyword is the user-defined function name. The pre-build
  pass should not flag the *defining* identifier (since the parser
  accepts it), but it absolutely should flag a `FUNCTION END()`
  attempt. Easiest: special-case the token immediately after
  `FUNCTION ` / `SUB `.

### Bonus checks (cheap once we have the AST-ish split)

- Unbalanced FOR / NEXT / IF / END IF / DO / LOOP.
- Calls to undefined functions (compare against parsed FUNCTION
  declarations).
- Trailing `:` with nothing after (interpreter accepts but reads
  weird).
- Mismatched DIM size vs subscript usage.

These are bigger lifts; ship the reserved-word check first.

## Why we deferred

- All three demos (RPG, shooter, map editor) are now reserved-word-
  clean; further edits will hit the same wall but we know the
  workaround now.
- Linter scope creep risk: once "warnings in editor" exists,
  pressure to expand it (typo detection, name suggestions) eats
  time better spent on game features.
- Right time: when a tutorial author or a new community contributor
  hits the same pothole and asks why their `STEP` variable doesn't
  work.
