#!/usr/bin/env python3
"""
Headless canvas (basic-wasm-canvas) test: INPUT and GET must not freeze the tab.

Requires: make basic-wasm-canvas, pip install -r tests/requirements-wasm.txt,
          python -m playwright install chromium
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

    def run() -> None:
        httpd.serve_forever()

    threading.Thread(target=run, daemon=True).start()
    return httpd, httpd.server_address[1]


def main() -> int:
    need = [
        WEB / "basic-canvas.js",
        WEB / "basic-canvas.wasm",
        WEB / "canvas.html",
    ]
    for p in need:
        if not p.is_file():
            print(f"error: missing {p}; run: make basic-wasm-canvas", file=sys.stderr)
            return 1

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("error: pip install -r tests/requirements-wasm.txt", file=sys.stderr)
        print("       python -m playwright install chromium", file=sys.stderr)
        return 1

    httpd, port = _serve_web()
    base = f"http://127.0.0.1:{port}/canvas.html"
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1100, "height": 900})

            def run_canvas_case(
                name: str,
                program: str,
                after_run,
            ) -> None:
                page.goto(base, wait_until="networkidle", timeout=120000)
                page.wait_for_function(
                    "() => !document.getElementById('run').disabled",
                    timeout=120000,
                )
                page.fill("#program", program)
                page.click("#run")
                after_run(page)
                page.wait_for_function(
                    "() => window.Module && window.Module.wasmGfxRunDone === 1",
                    timeout=90000,
                )
                print(f"wasm_browser_canvas_test: {name} OK")

            # INPUT: type into focused canvas after run
            def input_keys(pg):
                pg.click("#screen")
                pg.wait_for_timeout(100)
                pg.keyboard.type("xy")
                pg.keyboard.press("Enter")

            run_canvas_case(
                "INPUT",
                '10 INPUT "N"; A$\n20 PRINT A$\n30 END\n',
                input_keys,
            )

            run_canvas_case(
                "INPUT_NAME",
                '10 INPUT "NAME"; A$\n20 PRINT A$\n30 END\n',
                input_keys,
            )

            # GET: one key after run (program prints then waits)
            def get_key(pg):
                pg.click("#screen")
                pg.wait_for_timeout(100)
                pg.keyboard.press("z")

            run_canvas_case(
                "GET",
                '10 PRINT "GO"\n20 GET A$\n30 END\n',
                get_key,
            )

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_browser_canvas_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
