#!/usr/bin/env python3
"""Playwright smoke test for web/tutorial-example.html (basic-wasm-modular + tutorial-embed.js)."""
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

    def run() -> None:
        httpd.serve_forever()

    threading.Thread(target=run, daemon=True).start()
    return httpd, httpd.server_address[1]


def main() -> int:
    for name in ("basic-modular.js", "basic-modular.wasm", "tutorial-embed.js", "tutorial-example.html"):
        if not (WEB / name).is_file():
            print(f"error: web/{name} not found; run: make basic-wasm-modular", file=sys.stderr)
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
    url = f"http://127.0.0.1:{port}/tutorial-example.html"
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1100, "height": 900})
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function(
                "() => document.querySelectorAll('.cbm-tutorial-embed').length === 2",
                timeout=120000,
            )
            page.wait_for_function(
                "() => document.querySelectorAll('.cbm-tutorial-toolbar button').length >= 2",
                timeout=120000,
            )
            # First embed: wait for Run enabled, click first Run only
            page.wait_for_function(
                """() => {
                  const b = document.querySelector('#ex1 .cbm-tutorial-toolbar button');
                  return b && !b.disabled && b.textContent === 'Run';
                }""",
                timeout=120000,
            )
            page.evaluate("document.querySelector('#ex1 .cbm-tutorial-toolbar button').click()")
            page.wait_for_function(
                "() => (document.querySelector('#ex1 .cbm-tutorial-output').textContent || '').includes('FIRST EXAMPLE')",
                timeout=120000,
            )
            # Second embed (no editor): second Run button
            page.wait_for_function(
                """() => {
                  const rows = document.querySelectorAll('#ex2 .cbm-tutorial-toolbar button');
                  return rows[0] && !rows[0].disabled;
                }""",
                timeout=60000,
            )
            page.evaluate("document.querySelector('#ex2 .cbm-tutorial-toolbar button').click()")
            page.wait_for_function(
                "() => (document.querySelector('#ex2 .cbm-tutorial-output').textContent || '').includes('SECOND EXAMPLE')",
                timeout=120000,
            )
            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_tutorial_embed_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
