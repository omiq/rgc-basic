"""Regression tests for portability walker false positives."""

from __future__ import annotations

import unittest

from .tokenizer import tokenize
from .walker import lint


def _lint(source: str, *, tier: str = "portable") -> list[str]:
    return [d.message for d in lint(tokenize(source), file="t.bas", tier=tier)]


class WalkerStringLiteralTests(unittest.TestCase):
    def test_keywords_inside_print_strings_are_ignored(self):
        msgs = _lint('print " ENTER A NUMBER       4  3  2"')
        self.assertFalse(any("NUMBER" in m for m in msgs))

        msgs = _lint(
            'print "\\nWARP ENGINES SHUT DOWN AT "; print "SECTOR "'
        )
        self.assertFalse(any("DOWN" in m for m in msgs))

    def test_down_statement_still_warns(self):
        msgs = _lint("down")
        self.assertTrue(any("DOWN" in m for m in msgs))


if __name__ == "__main__":
    unittest.main()
