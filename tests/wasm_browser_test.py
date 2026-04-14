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
import time
from functools import partial
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"


def _click_run(page) -> None:
    page.evaluate("document.getElementById('run').click()")


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
            _click_run(page)
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('HELLO, WORLD!')",
                timeout=60000,
            )

            # PRINT without ; must become separate HTML lines (stdout buffered until newline)
            page.fill(
                "#program",
                '10 PRINT "FIRST"\n20 PRINT "SECOND"\n30 END\n',
            )
            _click_run(page)
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('SECOND')",
                timeout=60000,
            )
            br_count = page.eval_on_selector_all("#output br", "els => els.length")
            if br_count < 2:
                raise RuntimeError(f"expected >=2 <br> for PRINT newlines, got {br_count}")

            # INPUT uses inline field (not prompt)
            page.fill(
                "#program",
                '10 INPUT "N"; N\n20 PRINT N\n30 END\n',
            )
            _click_run(page)
            page.wait_for_selector("#inputLineRow.active", timeout=60000)
            page.fill("#inputLine", "99")
            page.press("#inputLine", "Enter")
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('99')",
                timeout=60000,
            )

            # GET poll loop (terminal wasm): must yield when queue empty or tab freezes
            page.fill(
                "#program",
                '10 PRINT "OK"\n'
                "20 GET K$\n"
                '30 IF K$="" THEN GOTO 20\n'
                "40 PRINT K$\n"
                "50 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('OK')",
                timeout=60000,
            )
            page.evaluate(
                "() => { Module.ccall('wasm_push_key', null, ['number'], [88]); }"
            )
            page.wait_for_function(
                "() => (window.Module && Module.wasmRunDone === 1)",
                timeout=120000,
            )
            out = page.text_content("#output") or ""
            if "X" not in out:
                raise RuntimeError(f"GET poll: expected key X in output, got {out!r}")

            # Pause / Stop: infinite loop must still finish when Stop is pressed
            page.fill(
                "#program",
                "10 I=0\n"
                "20 I=I+1\n"
                "30 GOTO 20\n",
            )
            _click_run(page)
            page.wait_for_function(
                """() => {
                  const p = document.getElementById('pause');
                  return p && !p.disabled;
                }""",
                timeout=60000,
            )
            page.evaluate("Module.wasmPaused = 1")
            time.sleep(0.25)
            page.evaluate(
                "Module.wasmStopRequested = 1; Module.wasmPaused = 0"
            )
            page.wait_for_function(
                "() => (window.Module && Module.wasmRunDone === 1)",
                timeout=120000,
            )

            # EXEC$ host hook (Module.rgcHostExec) — see docs/wasm-host-exec.md
            page.fill(
                "#program",
                '10 R$ = EXEC$("__wasm_browser_host_exec_test__")\n'
                '20 IF R$ <> "HOST_OK" THEN PRINT "HOSTBAD"; R$ : END\n'
                '30 PRINT "HOST_EXEC_OK"\n'
                "40 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('HOST_EXEC_OK')",
                timeout=120000,
            )

            # HTTP$ / HTTPSTATUS: async fetch (Asyncify + wasm_js_http_fetch_async)
            page.fill(
                "#program",
                '10 U$ = "https://httpbin.org/get"\n'
                "20 R$ = HTTP$(U$)\n"
                "30 S = HTTPSTATUS()\n"
                '40 IF S <> 200 THEN PRINT "BADSTATUS"; S : END\n'
                '50 IF INSTR(R$, "httpbin") < 1 THEN PRINT "NOBODY" : END\n'
                '60 PRINT "HTTP_OK"\n'
                "70 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (document.getElementById('output').textContent || '').includes('HTTP_OK')",
                timeout=120000,
            )

            # HTTPFETCH + binary OPEN/GETBYTE (MEMFS)
            fetch_prog = (
                '10 U$ = "http://127.0.0.1:%d/wasm_httpfetch_test.bin"\n'
                '20 P$ = "/fetch_test.bin"\n'
                "30 S = HTTPFETCH(U$, P$)\n"
                "40 IF HTTPSTATUS() <> 200 THEN PRINT \"BADSTATUS\"; HTTPSTATUS() : END\n"
                '50 OPEN 1,1,0,"rb:/fetch_test.bin"\n'
                "60 GETBYTE #1, B1\n"
                "70 GETBYTE #1, B2\n"
                "80 GETBYTE #1, B3\n"
                "90 GETBYTE #1, B4\n"
                "100 GETBYTE #1, B5\n"
                "110 CLOSE 1\n"
                "120 IF B1<>1 OR B2<>2 OR B3<>3 OR B4<>4 OR B5<>255 THEN PRINT \"BYTEBAD\"; B1; B2; B3; B4; B5 : END\n"
                '130 PRINT "FETCH_BYTES_OK"\n'
                "140 END\n"
            ) % port
            page.fill("#program", fetch_prog)
            _click_run(page)
            try:
                page.wait_for_function(
                    "() => (document.getElementById('output').textContent || '').includes('FETCH_BYTES_OK')",
                    timeout=120000,
                )
            except Exception:
                out = page.text_content("#output") or ""
                raise RuntimeError(f"HTTPFETCH/GETBYTE test failed; output={out!r}") from None

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_browser_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
