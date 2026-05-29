#!/bin/sh
# Drift guard: every keyword/built-in the runtime defines in basic.c
# must have a tier entry in rules.json. If basic.c grows a new keyword
# (reserved_words[], the eval_factor allow-list, or kconst[]) and nobody
# tiers it, the linter goes blind to it AND the docs lag — this test
# fails so the gap is closed at add-time, not discovered later.
#
# Run from the repo root: sh tools/rgc_lint/test_drift.sh
# Exits non-zero if basic.c has any keyword absent from rules.json.

set -e
cd "$(dirname "$0")/../.."

python3 - <<'PY'
import sys
from tools.rgc_lint.extract_keywords import canonical_set
from tools.rgc_lint.walker import load_rules

runtime = canonical_set()
tiered = set(load_rules().keys())

missing = sorted(runtime - tiered)   # in basic.c, no tier -> linter blind
if missing:
    print(f"==> rgc-lint DRIFT: {len(missing)} keyword(s) in basic.c with no rules.json tier:")
    for k in missing:
        print(f"    {k}")
    print("    -> add a tier entry (portable/modern/conditional) to "
          "tools/rgc_lint/rules.json")
    sys.exit(1)

# Reverse direction is advisory only: rules.json legitimately carries
# ugBASIC-target keywords (COPPER, FLASH...) and two-word verbs (DRAW,
# RESET...) that aren't standalone names in basic.c. Report, don't fail.
extra = sorted(tiered - runtime)
if extra:
    print(f"==> rgc-lint: {len(extra)} rules.json entr(y/ies) not in basic.c "
          f"name tables (expected for target-only/two-word verbs): "
          + ", ".join(extra))

print(f"==> rgc-lint: no drift — all {len(runtime)} runtime keywords tiered")
PY
