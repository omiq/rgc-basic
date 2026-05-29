"""Generate the agent-facing language spec from the single source of truth.

Joins the canonical keyword set (extract_keywords.py, parsed from
basic.c) with the portability tiers/notes (rules.json) and emits:

  spec.json                       — machine-readable inventory for agents
  docs/rgc-basic-llm-guide.md     — the keyword tables between the
                                    <!-- BEGIN/END GENERATED ... --> markers

Both are committed so consumers don't need to run this, and a --check
mode (wired into `make lint`) fails if either is stale — same drift
discipline as test_drift.sh, extended to the docs.

Usage:
    python3 -m tools.rgc_lint.gen_spec            # write spec.json + guide
    python3 -m tools.rgc_lint.gen_spec --check    # fail if either is stale
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from .extract_keywords import keyword_kinds
from .walker import load_rules

_REPO_ROOT = Path(__file__).resolve().parents[2]
_SPEC_PATH = _REPO_ROOT / "spec.json"
_GUIDE_PATH = _REPO_ROOT / "docs" / "rgc-basic-llm-guide.md"

_BEGIN = "<!-- BEGIN GENERATED KEYWORDS -->"
_END = "<!-- END GENERATED KEYWORDS -->"

_TIER_BLURB = {
    "portable": "runs on rgc-basic and transpiles to ugBASIC retro targets",
    "modern": "rgc-basic only (native + WASM); no retro/ugBASIC equivalent",
    "conditional": "runs everywhere but behaviour/availability varies by target",
    "param": "tier depends on the argument (see note)",
}


def build_spec() -> dict:
    """Assemble the spec dict from basic.c kinds + rules.json tiers."""
    kinds = keyword_kinds()
    rules = load_rules()

    entries = []
    for name in sorted(kinds):
        rule = rules.get(name, {})
        entry = {
            "name": name,
            "kind": kinds[name],          # keyword | function | constant
            "tier": rule.get("tier", "modern"),
        }
        if rule.get("note"):
            entry["note"] = rule["note"]
        if rule.get("suggest"):
            entry["suggest"] = rule["suggest"]
        if rule.get("params"):
            entry["params"] = rule["params"]
        entries.append(entry)

    by_kind: dict[str, int] = {}
    by_tier: dict[str, int] = {}
    for e in entries:
        by_kind[e["kind"]] = by_kind.get(e["kind"], 0) + 1
        by_tier[e["tier"]] = by_tier.get(e["tier"], 0) + 1

    return {
        "language": "rgc-basic",
        "source_of_truth": "basic.c (reserved_words[], eval_factor allow-list, "
                           "kconst[], statement dispatcher) joined with "
                           "tools/rgc_lint/rules.json",
        "generator": "tools/rgc_lint/gen_spec.py",
        "tiers": {k: _TIER_BLURB[k] for k in sorted(by_tier)},
        "counts": {"total": len(entries), "by_kind": by_kind, "by_tier": by_tier},
        "keywords": entries,
    }


def _render_spec_json(spec: dict) -> str:
    return json.dumps(spec, indent=2) + "\n"


def _render_keyword_tables(spec: dict) -> str:
    """Markdown tables for the guide, one per kind, tier-annotated."""
    out: list[str] = []
    label = {"keyword": "Statements / keywords",
             "function": "Functions",
             "constant": "Constants"}
    for kind in ("keyword", "function", "constant"):
        names = [e for e in spec["keywords"] if e["kind"] == kind]
        if not names:
            continue
        out.append(f"### {label[kind]} ({len(names)})\n")
        out.append("| name | tier | note |")
        out.append("| --- | --- | --- |")
        for e in names:
            note = e.get("note", "") or e.get("suggest", "")
            note = note.replace("|", "\\|")
            out.append(f"| `{e['name']}` | {e['tier']} | {note} |")
        out.append("")
    return "\n".join(out)


def _splice_guide(existing: str, tables: str) -> str:
    """Replace the content between the generated markers in the guide."""
    if _BEGIN not in existing or _END not in existing:
        raise RuntimeError(
            f"guide is missing the {_BEGIN} / {_END} markers — "
            f"add them where the keyword tables should go"
        )
    head = existing.split(_BEGIN)[0]
    tail = existing.split(_END)[1]
    return f"{head}{_BEGIN}\n\n{tables}\n{_END}{tail}"


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    check = "--check" in argv

    spec = build_spec()
    spec_text = _render_spec_json(spec)
    tables = _render_keyword_tables(spec)

    if not _GUIDE_PATH.exists():
        print(f"gen_spec: {_GUIDE_PATH} not found — create it with the "
              f"{_BEGIN}/{_END} markers first", file=sys.stderr)
        return 2
    guide_text = _splice_guide(_GUIDE_PATH.read_text(encoding="utf-8"), tables)

    if check:
        stale = []
        if not _SPEC_PATH.exists() or _SPEC_PATH.read_text(encoding="utf-8") != spec_text:
            stale.append(str(_SPEC_PATH.relative_to(_REPO_ROOT)))
        if _GUIDE_PATH.read_text(encoding="utf-8") != guide_text:
            stale.append(str(_GUIDE_PATH.relative_to(_REPO_ROOT)))
        if stale:
            print("==> gen_spec STALE: " + ", ".join(stale))
            print("    regenerate: python3 -m tools.rgc_lint.gen_spec")
            return 1
        print(f"==> gen_spec: spec.json + guide current "
              f"({spec['counts']['total']} keywords)")
        return 0

    _SPEC_PATH.write_text(spec_text, encoding="utf-8")
    _GUIDE_PATH.write_text(guide_text, encoding="utf-8")
    print(f"==> gen_spec: wrote spec.json + guide ({spec['counts']['total']} keywords)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
