#!/usr/bin/env python3
"""Headless regression tests for #OPTION charset lower + ASCII/CHR$ on canvas WASM.

Catches wrong gfx_put_byte mapping (space as !, CHR$(65) wrong vs "A", IDE without -petscii).
Requires: make basic-wasm-canvas, pip install -r tests/requirements-wasm.txt, playwright install chromium.
"""
from __future__ import annotations

import http.server
import socketserver
import sys
import threading
import time
from functools import partial
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"


def _serve_web() -> tuple[socketserver.TCPServer, int]:
    Handler = partial(http.server.SimpleHTTPRequestHandler, directory=str(WEB))
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", 0), Handler)
    port = httpd.server_address[1]

    def run() -> None:
        httpd.serve_forever()

    threading.Thread(target=run, daemon=True).start()
    return httpd, port


def _click_run(page) -> None:
    page.evaluate("document.getElementById('run').click()")


def _canvas_pixel_rgba(page, x: int, y: int) -> tuple[int, int, int, int]:
    return page.evaluate(
        """([x, y]) => {
      const c = document.getElementById('screen');
      const ctx = c.getContext('2d');
      const d = ctx.getImageData(x, y, 1, 1).data;
      return [d[0], d[1], d[2], d[3]];
    }""",
        [x, y],
    )


def _set_petscii(page, on: bool) -> None:
    page.evaluate(f"() => {{ document.getElementById('optPetscii').checked = {str(on).lower()}; }}")


def _run_charset_suite(page, *, petscii_checked: bool) -> None:
    """Assert mixed-case string, space, and CHR$(65) match \"A\" on same charset."""
    label = "petscii on" if petscii_checked else "petscii off"
    _set_petscii(page, petscii_checked)
    page.wait_for_function("() => !document.getElementById('run').disabled", timeout=60000)

    # Line 0: mixed case + spaces (user-reported pattern)
    page.fill(
        "#program",
        '#OPTION charset lower\n'
        '10 COLOR 1\n'
        '20 BACKGROUND 6\n'
        '30 PRINT "hEY hEY"\n'
        '40 PRINT CHR$(32)\n'
        '50 PRINT CHR$(65)\n'
        '60 PRINT "A"\n'
        "70 END\n",
    )
    _click_run(page)
    page.wait_for_function(
        "() => (window.Module && Module.wasmGfxRunDone === 1)",
        timeout=120000,
    )
    log = page.text_content("#log") or ""
    if log.strip():
        raise RuntimeError(f"{label}: error log: {log!r}")

    # Row 0 "hEY hEY" — space between words at column 3 (0-based), center x = 3*8+4 = 28
    px_h = _canvas_pixel_rgba(page, 4, 4)
    px_space_word = _canvas_pixel_rgba(page, 28, 4)
    if list(px_h[:3]) == list(px_space_word[:3]):
        raise RuntimeError(
            f"{label}: first 'h' vs space in 'hEY hEY' should differ, got h={px_h!r} sp={px_space_word!r}"
        )

    # CHR$(32) line: only a space — interior of cell should match word-space (both true space)
    px_chr32 = _canvas_pixel_rgba(page, 4, 12)
    if list(px_chr32[:3]) != list(px_space_word[:3]):
        raise RuntimeError(
            f"{label}: CHR$(32) center should match literal space pixel, "
            f"chr32={px_chr32!r} lit_sp={px_space_word!r}"
        )

    # CHR$(65) vs "A" on next lines (y=20 and y=28 for rows 2 and 3 at cell center y=4+8*r)
    px_chr65 = _canvas_pixel_rgba(page, 4, 20)
    px_quote_a = _canvas_pixel_rgba(page, 4, 28)
    if list(px_chr65[:3]) != list(px_quote_a[:3]):
        raise RuntimeError(
            f"{label}: CHR$(65) vs PRINT \"A\" should match at (4,20) vs (4,28), "
            f"chr65={px_chr65!r} qA={px_quote_a!r}"
        )


def main() -> int:
    if not (WEB / "basic-canvas.js").is_file() or not (WEB / "basic-canvas.wasm").is_file():
        print("error: run make basic-wasm-canvas first", file=sys.stderr)
        return 1
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "error: pip install -r tests/requirements-wasm.txt && playwright install chromium",
            file=sys.stderr,
        )
        return 1

    httpd, port = _serve_web()
    url = f"http://127.0.0.1:{port}/canvas.html"
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1100, "height": 900})
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function("() => !document.getElementById('run').disabled", timeout=120000)

            _run_charset_suite(page, petscii_checked=True)
            _run_charset_suite(page, petscii_checked=False)
            _set_petscii(page, True)

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_canvas_charset_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
