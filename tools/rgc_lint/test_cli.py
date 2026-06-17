"""Regression tests for the rgc-lint CLI, esp. --check-transpile accuracy.

--check-transpile answers "does this transpile to C?" — a different axis from
the ugBASIC-portability tier lint. A file using `modern` keywords (SELECT,
CONTINUE, DICT…) is not ugBASIC-portable but transpiles to C cleanly; the
transpile check must not report it as failing.
"""

from __future__ import annotations

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from .cli import main

# Repo root: tools/rgc_lint/test_cli.py -> ../../..
_ROOT = Path(__file__).resolve().parents[2]


def _ex(name: str) -> str:
    return str(_ROOT / "examples" / name)


def _run(*argv: str) -> tuple[int, str]:
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = main(list(argv))
    return code, buf.getvalue()


class CheckTranspileTests(unittest.TestCase):
    def test_modern_keywords_transpile_despite_tier(self):
        # SELECT is `modern` (not ugBASIC-portable) but transpiles to C.
        code, out = _run("--check-transpile", _ex("trek-portable.bas"))
        self.assertEqual(code, 0, out)
        self.assertIn("transpiles to C", out)
        self.assertNotIn("not portable", out)

    def test_real_blocker_still_fails(self):
        code, out = _run("--check-transpile", _ex("petscii-data.bas"))
        self.assertEqual(code, 1)
        self.assertIn("does not transpile to C", out)

    def test_tier_lint_unchanged_without_flag(self):
        # Without --check-transpile the ugBASIC tier axis still flags modern kw.
        code, out = _run(_ex("trek-portable.bas"))
        self.assertEqual(code, 1)
        self.assertIn("not portable", out)


if __name__ == "__main__":
    unittest.main()
