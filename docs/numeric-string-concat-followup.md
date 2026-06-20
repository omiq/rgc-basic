# Follow-up: numeric `+` into a string emits crashing C (silent int→char\*)

## Symptom

`"text " + N + " more"` where `N` is a **numeric** variable transpiles to C that
casts the int to `char *` and lets the print/concat helper deref it. On a target
with no memory protection (e.g. ZX Spectrum via z88dk) this reads random RAM as
a string → garbage glyphs and, when the bad pointer lands badly, a full machine
**reset**.

Observed 2026-06-20 in `examples/trek-portable.bas` on `--target zxspectrum`:
the two NavWarning lines and the repair-ETA prompt concatenated bare numerics
(`SECTOR_X`, `SECTOR_Y`, `QUADRANT_*`, `D3`) into strings without `str$()`.
sdcc flagged it as `warning 154: converting integral to pointer without a cast
... const-char generic*` — the warning was the smoking gun, but it is non-fatal
so the build shipped crashing code.

Worked around by wrapping each numeric operand in `str$()` (matching the
convention already used elsewhere in the same file, e.g. the SHIELD message).

## Why it matters

- The interpreter is (apparently) more forgiving than the emitted C, so portable
  code can pass `make lint` / run under the interpreter and still crash once
  transpiled. That breaks the "lint = portable" contract.
- It fails **silently at runtime** on the least-protected targets — exactly the
  ones hardest to debug (no console, machine resets).

## Options (pick one or both)

1. **Lint error** (in `tools/rgc_lint`): flag a `+` whose operand is numeric and
   the other side is a string literal/`$` var. Cheap, catches it at author time,
   lives in the public repo so it guards every backend. Preferred first step.
2. **Auto-stringify in the C emitter** (`rgc-transpiler` `rgcx/c/emit_c.py`):
   when a string concat sees a numeric operand, wrap it in the `str$` helper
   automatically, matching interpreter semantics. Removes the foot-gun entirely
   but needs the type info at the concat site and must agree with whatever the
   interpreter actually does (verify the interpreter coerces rather than errors
   before committing to this).

Decide #2 only after confirming the interpreter's behaviour for `"x" + 5` — if
the interpreter also errors, then #1 (lint) is the whole fix and the emitter is
correct to refuse.

## Pointers

- Crash sites were `examples/trek-portable.bas` lines ~402, ~418, ~685.
- Emitter concat path: `rgc-transpiler/rgcx/c/emit_c.py` (string `+` handling).
- The sdcc signal to grep emitted C for: `warning 154 ... integral to pointer`.
