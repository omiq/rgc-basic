#!/usr/bin/env python3
"""
Headless browser smoke test for the Emscripten build.
Requires: make basic-wasm, pip install -r tests/requirements-wasm.txt, playwright install chromium
"""
from __future__ import annotations

import http.server
import socketserver
import sys
import threading
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


def main() -> int:
    if not (WEB / "basic.js").is_file() or not (WEB / "basic.wasm").is_file():
        print("error: web/basic.js and web/basic.wasm not found; run: make basic-wasm", file=sys.stderr)
        return 1
    if not (WEB / "index.html").is_file():
        print("error: web/index.html not found", file=sys.stderr)
        return 1

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("error: install tests deps: pip install -r tests/requirements-wasm.txt", file=sys.stderr)
        print("       then: python -m playwright install chromium", file=sys.stderr)
        return 1

    httpd, port = _serve_web()
    url = f"http://127.0.0.1:{port}/"
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1100, "height": 900})
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=120000,
            )
            page.click("#run")
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('HELLO, WORLD!')",
                timeout=60000,
            )

            # INPUT uses inline field (not prompt)
            page.fill(
                "#program",
                '10 INPUT "N"; N\n20 PRINT N\n30 END\n',
            )
            page.click("#run")
            page.wait_for_selector("#inputLineRow.active", timeout=60000)
            page.fill("#inputLine", "99")
            page.press("#inputLine", "Enter")
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('99')",
                timeout=60000,
            )

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_browser_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
