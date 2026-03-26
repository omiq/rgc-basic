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


def _run_charset_suite(page, *, petscii_checked: bool, numbered_option: bool) -> None:
    """Assert mixed-case string, space, and CHR$(65) match \"A\" on same charset."""
    label = ("petscii on" if petscii_checked else "petscii off") + (
        ", numbered #OPTION" if numbered_option else ", bare #OPTION"
    )
    _set_petscii(page, petscii_checked)
    page.wait_for_function("() => !document.getElementById('run').disabled", timeout=60000)

    if numbered_option:
        opt = "10 #OPTION charset lower\n"
        rest = (
            "20 COLOR 1\n"
            "30 BACKGROUND 6\n"
            '40 PRINT "hEY hEY"\n'
            "50 PRINT CHR$(32)\n"
            "60 PRINT CHR$(65)\n"
            '70 PRINT "A"\n'
            "80 END\n"
        )
    else:
        opt = "#OPTION charset lower\n"
        rest = (
            "10 COLOR 1\n"
            "20 BACKGROUND 6\n"
            '30 PRINT "hEY hEY"\n'
            "40 PRINT CHR$(32)\n"
            "50 PRINT CHR$(65)\n"
            '60 PRINT "A"\n'
            "70 END\n"
        )

    # Line 0: mixed case + spaces (user-reported pattern)
    page.fill("#program", opt + rest)
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
    y_chr32 = 20 if numbered_option else 12
    y_chr65 = 28 if numbered_option else 20
    y_quote_a = 36 if numbered_option else 28
    px_chr32 = _canvas_pixel_rgba(page, 4, y_chr32)
    if list(px_chr32[:3]) != list(px_space_word[:3]):
        raise RuntimeError(
            f"{label}: CHR$(32) center should match literal space pixel, "
            f"chr32={px_chr32!r} lit_sp={px_space_word!r}"
        )

    # CHR$(65) vs "A" on next lines (y=20 and y=28 for rows 2 and 3 at cell center y=4+8*r)
    px_chr65 = _canvas_pixel_rgba(page, 4, y_chr65)
    px_quote_a = _canvas_pixel_rgba(page, 4, y_quote_a)
    if list(px_chr65[:3]) != list(px_quote_a[:3]):
        raise RuntimeError(
            f"{label}: CHR$(65) vs PRINT \"A\" should match, "
            f"chr65={px_chr65!r} qA={px_quote_a!r}"
        )


def _run_user_four_line_repro(page) -> None:
    """Exact user repro: #OPTION charset lower + four PRINTs; PETSCII off, charset lower UI."""
    _set_petscii(page, False)
    page.wait_for_function("() => !document.getElementById('run').disabled", timeout=60000)
    page.fill(
        "#program",
        "#OPTION charset lower\n"
        'PRINT "hEY hEY"\n'
        "PRINT CHR$(32)\n"
        'PRINT "TEST test"\n'
        "PRINT CHR$(65)\n"
        "END\n",
    )
    _click_run(page)
    page.wait_for_function(
        "() => (window.Module && Module.wasmGfxRunDone === 1)",
        timeout=120000,
    )
    log = page.text_content("#log") or ""
    if log.strip():
        raise RuntimeError(f"user repro: error log: {log!r}")
    # Row 2 "TEST test": both lowercase 't' (cols 5 and 8) must match (not uftu +1 bug)
    y = 4 + 8 * 2 + 4
    px_t1 = _canvas_pixel_rgba(page, 5 * 8 + 4, y)
    px_t2 = _canvas_pixel_rgba(page, 8 * 8 + 4, y)
    if list(px_t1[:3]) != list(px_t2[:3]):
        raise RuntimeError(
            f"user repro: two 't' in 'TEST test' should match, got t1={px_t1!r} t2={px_t2!r}"
        )
    # CHR$(65) row vs "A" would need another line index if we add; charset test already covers CHR65 vs A


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

            _run_charset_suite(page, petscii_checked=True, numbered_option=False)
            _run_charset_suite(page, petscii_checked=False, numbered_option=False)
            # Pasted "10 #OPTION ..." in numberless program (canvas / IDE)
            _run_charset_suite(page, petscii_checked=False, numbered_option=True)
            _run_charset_suite(page, petscii_checked=True, numbered_option=True)
            _run_user_four_line_repro(page)
            _set_petscii(page, True)

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_canvas_charset_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
