#!/usr/bin/env python3
"""Playwright tests for web/canvas.html (basic-wasm-canvas)."""
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
    """Dispatch Run without Playwright actionability (rAF can keep layout 'unstable')."""
    page.evaluate("document.getElementById('run').click()")


def _canvas_top_left_rgba(page) -> tuple[int, int, int, int]:
    return page.evaluate(
        """() => {
      const c = document.getElementById('screen');
      const ctx = c.getContext('2d');
      const d = ctx.getImageData(0, 0, 1, 1).data;
      return [d[0], d[1], d[2], d[3]];
    }"""
    )


def main() -> int:
    if not (WEB / "basic-canvas.js").is_file() or not (WEB / "basic-canvas.wasm").is_file():
        print(
            "error: web/basic-canvas.js and .wasm not found; run: make basic-wasm-canvas",
            file=sys.stderr,
        )
        return 1
    if not (WEB / "canvas.html").is_file():
        print("error: web/canvas.html not found", file=sys.stderr)
        return 1

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("error: pip install -r tests/requirements-wasm.txt && playwright install chromium", file=sys.stderr)
        return 1

    httpd, port = _serve_web()
    url = f"http://127.0.0.1:{port}/canvas.html"
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1100, "height": 900})
            page.goto(url, wait_until="networkidle", timeout=120000)
            page.wait_for_function("() => !document.getElementById('run').disabled", timeout=120000)

            before = _canvas_top_left_rgba(page)

            # Long loop + SLEEP: canvas must refresh (top-left pixel changes from idle frame).
            page.fill(
                "#program",
                "10 FOR I=1 TO 200\n"
                "20 POKE 1024,(I AND 255)\n"
                "30 SLEEP 1\n"
                "40 NEXT I\n"
                "50 END\n",
            )
            _click_run(page)
            time.sleep(1.5)
            mid = _canvas_top_left_rgba(page)
            if mid == before:
                browser.close()
                raise RuntimeError(
                    "canvas pixel unchanged during SLEEP loop (expected live refresh)"
                )

            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log = page.text_content("#log") or ""
            if log.strip():
                browser.close()
                raise RuntimeError(f"unexpected canvas error log: {log!r}")

            # Pause / Resume: long FOR/NEXT (yields on NEXT); screen frozen while wasmPaused
            page.fill(
                "#program",
                "10 FOR I=1 TO 500000\n"
                "20 POKE 1024,(I AND 255)\n"
                "30 NEXT I\n"
                "40 END\n",
            )
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            # force: canvas rAF can keep layout "unstable" for Playwright's actionability check
            _click_run(page)
            page.wait_for_function(
                """() => {
                  const p = document.getElementById('pause');
                  return p && !p.disabled;
                }""",
                timeout=60000,
            )
            time.sleep(0.35)
            # Long FOR/NEXT yields on NEXT; pause via same flag as Pause button
            page.evaluate("Module.wasmPaused = 1")
            time.sleep(0.35)
            px1 = _canvas_top_left_rgba(page)
            time.sleep(0.45)
            px2 = _canvas_top_left_rgba(page)
            if px1 != px2:
                browser.close()
                raise RuntimeError(
                    f"canvas changed while paused (expected frozen frame): {px1!r} vs {px2!r}"
                )
            page.evaluate("Module.wasmPaused = 0")
            time.sleep(0.35)
            px3 = _canvas_top_left_rgba(page)
            if px3 == px1:
                browser.close()
                raise RuntimeError(
                    f"canvas did not advance after resume (expected change): {px1!r} -> {px3!r}"
                )
            page.evaluate("Module.wasmStopRequested = 1")
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log3 = page.text_content("#log") or ""
            if log3.strip():
                browser.close()
                raise RuntimeError(f"pause/resume run error log: {log3!r}")

            # Nested FOR/NEXT
            page.fill(
                "#program",
                "10 FOR Y=1 TO 2\n"
                "20 FOR C=0 TO 3\n"
                "30 POKE 1024+C,C\n"
                "40 NEXT C\n"
                "50 NEXT Y\n"
                "60 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=60000,
            )
            log2 = page.text_content("#log") or ""
            if "NEXT without FOR" in log2 or log2.strip():
                browser.close()
                raise RuntimeError(f"nested FOR failed or error: {log2!r}")

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_browser_canvas_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
