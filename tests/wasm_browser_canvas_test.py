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
GFX_CANVAS_DEMO_BAS = ROOT / "examples" / "gfx_canvas_demo.bas"
TREK_BAS = ROOT / "examples" / "trek.bas"


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
            # rAF + Asyncify: allow several frames for POKE/NEXT to advance after resume
            px3 = px1
            for _ in range(40):
                time.sleep(0.1)
                px3 = _canvas_top_left_rgba(page)
                if px3 != px1:
                    break
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

            # TAB(n) must advance the canvas cursor (GFX), not only stdout — same cell as SPC.
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                '10 PRINT "X";TAB(20);"Y"\n20 END\n',
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=60000,
            )
            log_tab = page.text_content("#log") or ""
            if log_tab.strip():
                browser.close()
                raise RuntimeError(f"TAB test error log: {log_tab!r}")
            sc_tab = page.evaluate(
                """() => {
                  const M = window.Module;
                  if (!M || !M._wasm_gfx_screen_screencode_at) return null;
                  return M.ccall('wasm_gfx_screen_screencode_at', 'number', ['number','number'], [20, 0]);
                }"""
            )
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                '10 PRINT "X";SPC(19);"Y"\n20 END\n',
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=60000,
            )
            log_spc = page.text_content("#log") or ""
            if log_spc.strip():
                browser.close()
                raise RuntimeError(f"SPC compare error log: {log_spc!r}")
            sc_spc = page.evaluate(
                """() => {
                  const M = window.Module;
                  if (!M || !M._wasm_gfx_screen_screencode_at) return null;
                  return M.ccall('wasm_gfx_screen_screencode_at', 'number', ['number','number'], [20, 0]);
                }"""
            )
            if sc_tab is None or sc_spc is None:
                browser.close()
                raise RuntimeError("wasm_gfx_screen_screencode_at not available; rebuild canvas WASM")
            if sc_tab != sc_spc or sc_tab < 0:
                browser.close()
                raise RuntimeError(
                    f"TAB vs SPC screen mismatch at (20,0): TAB={sc_tab!r} SPC={sc_spc!r}"
                )
            if sc_tab == 32:
                browser.close()
                raise RuntimeError(f"TAB left space at (20,0) (expected Y glyph): {sc_tab!r}")

            # GET is non-blocking (empty if no key) like C64; empty-queue path must still
            # yield (emscripten_sleep(0)) or trek.bas-style tight GET polls freeze the tab.
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 FOR I=1 TO 80\n"
                "20 GET A$\n"
                "30 NEXT I\n"
                "40 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_poll = page.text_content("#log") or ""
            if log_poll.strip():
                browser.close()
                raise RuntimeError(f"GET poll-yield test error log: {log_poll!r}")
            # GET after other statements must not block waiting for a key (no push).
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 REM done\n"
                "20 GET A$\n"
                "30 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=30000,
            )
            log_nb = page.text_content("#log") or ""
            if log_nb.strip():
                browser.close()
                raise RuntimeError(f"GET non-blocking tail test error log: {log_nb!r}")

            # Long single PRINT (many gfx_put_byte): must yield inside PRINT or browser hangs
            # (trek.bas packs heavy output; run_program only counts ':'-separated statements).
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                '10 PRINT STRING$(3000,".")\n20 END\n',
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_longp = page.text_content("#log") or ""
            if log_longp.strip():
                browser.close()
                raise RuntimeError(f"long PRINT yield test error log: {log_longp!r}")

            # PEEK(56320+code) / key_state[] must update during SLEEP (Asyncify): IDE embeds that
            # only use wasm_push_key would fail this; canvas.html writes HEAPU8 at wasm_gfx_key_state_ptr.
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 FOR I=1 TO 400\n"
                "20 IF PEEK(56320+87)<>0 THEN POKE 1024,33\n"
                "25 IF PEEK(56320+87)=0 THEN POKE 1024,32\n"
                "30 SLEEP 1\n"
                "40 NEXT I\n"
                "50 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                """() => {
                  const p = document.getElementById('pause');
                  return p && !p.disabled;
                }""",
                timeout=60000,
            )
            page.click("#screen")
            time.sleep(0.15)
            page.keyboard.down("w")
            time.sleep(0.55)
            key87 = page.evaluate(
                """() => {
              const M = window.Module;
              if (!M || !M._wasm_gfx_key_state_ptr || !M.HEAPU8) return -1;
              const b = M._wasm_gfx_key_state_ptr();
              if (!b) return -2;
              return M.HEAPU8[b + 87] | 0;
            }"""
            )
            page.keyboard.up("w")
            if key87 != 1:
                browser.close()
                raise RuntimeError(
                    f"PEEK key matrix: expected HEAPU8[key_state+87]==1 while W held during SLEEP, got {key87!r}"
                )
            page.evaluate("Module.wasmStopRequested = 1")
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_peek = page.text_content("#log") or ""
            if log_peek.strip():
                browser.close()
                raise RuntimeError(f"PEEK key matrix test error log: {log_peek!r}")

            # TI must advance across SLEEP frames in canvas WASM (wall-clock jiffies).
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 T0=TI\n"
                "20 FOR I=1 TO 120\n"
                "30 SLEEP 1\n"
                "40 IF TI<>T0 THEN 60\n"
                "50 NEXT I\n"
                "55 PRINT \"TI_STUCK\"\n"
                "56 END\n"
                "60 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_ti = page.text_content("#log") or ""
            if "TI_STUCK" in (log_ti or ""):
                browser.close()
                raise RuntimeError("TI did not advance across SLEEP (canvas WASM jiffy clock)")
            if log_ti.strip():
                browser.close()
                raise RuntimeError(f"TI/SLEEP test unexpected log: {log_ti!r}")

            # trek-like: string concat in a loop (GOSUB 5440 pattern) must yield (eval_addsub).
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                '10 Q$=STRING$(190," ")\n'
                '20 A$="   "\n'
                "30 FOR I=1 TO 600\n"
                '40 Q$=LEFT$(Q$,80)+A$+RIGHT$(Q$,107)\n'
                "50 NEXT I\n"
                '60 PRINT "OKCAT"\n'
                "70 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_cat = page.text_content("#log") or ""
            if log_cat.strip():
                browser.close()
                raise RuntimeError(f"string concat stress error log: {log_cat!r}")

            # GOTO-heavy loop (trek-style line hopping) must stay responsive (yield on GOTO).
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 N=0\n"
                "20 N=N+1\n"
                "30 IF N>8000 THEN 50\n"
                "40 GOTO 20\n"
                '50 PRINT "OKGOTO"\n'
                "60 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_goto = page.text_content("#log") or ""
            if log_goto.strip():
                browser.close()
                raise RuntimeError(f"GOTO stress error log: {log_goto!r}")

            # SCREEN 1 bitmap: top-left pixel should be pen colour (COLOR 1 = white)
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                "10 SCREEN 1\n"
                "20 COLOR 1\n"
                "30 BACKGROUND 6\n"
                "40 PSET 0,0\n"
                "50 SLEEP 30\n"
                "60 END\n",
            )
            _click_run(page)
            time.sleep(0.6)
            bmp_px = _canvas_top_left_rgba(page)
            if list(bmp_px[:3]) != [255, 255, 255]:
                browser.close()
                raise RuntimeError(
                    f"bitmap mode: expected white pixel at (0,0), got {bmp_px!r}"
                )
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_bm = page.text_content("#log") or ""
            if log_bm.strip():
                browser.close()
                raise RuntimeError(f"bitmap test error log: {log_bm!r}")

            # Bitmap test leaves SCREEN 1; PETSCII text tests need text mode.
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill("#program", "10 SCREEN 0\n20 END\n")
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_scr0 = page.text_content("#log") or ""
            if log_scr0.strip():
                browser.close()
                raise RuntimeError(f"SCREEN 0 reset error log: {log_scr0!r}")

            # PETSCII + #OPTION charset lower: ASCII string literals must map to lowercase
            # char ROM (space = sc 32, not PETSCII-mapped 32→33 which drew as "!").
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill(
                "#program",
                '#OPTION charset lower\n'
                '10 PRINT "X X"\n'
                "20 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_cs = page.text_content("#log") or ""
            if log_cs.strip():
                browser.close()
                raise RuntimeError(f"charset lower test error log: {log_cs!r}")
            px_space = _canvas_pixel_rgba(page, 12, 4)
            px_x = _canvas_pixel_rgba(page, 2, 4)
            if list(px_space[:3]) == list(px_x[:3]):
                browser.close()
                raise RuntimeError(
                    f"charset lower: space pixel should differ from 'X' body, "
                    f"got space={px_space!r} x={px_x!r}"
                )

            # Same with PETSCII *unchecked* (IDE may omit -petscii); #OPTION charset lower must still work.
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.evaluate("() => { document.getElementById('optPetscii').checked = false; }")
            page.fill(
                "#program",
                '#OPTION charset lower\n'
                '10 PRINT "X X"\n'
                "20 END\n",
            )
            _click_run(page)
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_cs2 = page.text_content("#log") or ""
            if log_cs2.strip():
                browser.close()
                raise RuntimeError(f"charset lower (no -petscii) error log: {log_cs2!r}")
            px_space2 = _canvas_pixel_rgba(page, 12, 4)
            px_x2 = _canvas_pixel_rgba(page, 2, 4)
            if list(px_space2[:3]) == list(px_x2[:3]):
                browser.close()
                raise RuntimeError(
                    f"charset lower without -petscii: space vs X body, "
                    f"space={px_space2!r} x={px_x2!r}"
                )
            page.evaluate("() => { document.getElementById('optPetscii').checked = true; }")

            # PNG sprite over PETSCII (software decode + alpha composite)
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.evaluate(
                """async () => {
              const r = await fetch('testfixtures/red8x8.png');
              const buf = await r.arrayBuffer();
              Module.FS.writeFile('/red8x8.png', new Uint8Array(buf));
            }"""
            )
            page.fill(
                "#program",
                '10 LOADSPRITE 0,"/red8x8.png"\n'
                "20 DRAWSPRITE 0,0,0,1\n"
                "30 SLEEP 40\n"
                "40 END\n",
            )
            _click_run(page)
            time.sleep(0.6)
            spr_px = _canvas_pixel_rgba(page, 4, 4)
            r, g, b = int(spr_px[0]), int(spr_px[1]), int(spr_px[2])
            if r < 200 or g > 80 or b > 80:
                browser.close()
                raise RuntimeError(
                    f"sprite composite: expected red at (4,4), got rgba={spr_px!r}"
                )
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_sp = page.text_content("#log") or ""
            if log_sp.strip():
                browser.close()
                raise RuntimeError(f"sprite test error log: {log_sp!r}")

            # Full example: examples/gfx_canvas_demo.bas + gfx_canvas_demo.png (served from web/)
            if not GFX_CANVAS_DEMO_BAS.is_file():
                browser.close()
                raise RuntimeError(f"missing {GFX_CANVAS_DEMO_BAS}")
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            demo_src = GFX_CANVAS_DEMO_BAS.read_text(encoding="utf-8")
            page.evaluate(
                """async () => {
              const r = await fetch('gfx_canvas_demo.png');
              const buf = await r.arrayBuffer();
              Module.FS.writeFile('/gfx_canvas_demo.png', new Uint8Array(buf));
            }"""
            )
            page.fill("#program", demo_src)
            _click_run(page)
            time.sleep(0.8)
            demo_px = _canvas_pixel_rgba(page, 104, 104)
            dr, dg, db = int(demo_px[0]), int(demo_px[1]), int(demo_px[2])
            if dr < 200 or dg > 80 or db > 80:
                browser.close()
                raise RuntimeError(
                    f"gfx_canvas_demo: expected red inside sprite at (104,104), got rgba={demo_px!r}"
                )
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=120000,
            )
            log_demo = page.text_content("#log") or ""
            if log_demo.strip():
                browser.close()
                raise RuntimeError(f"gfx_canvas_demo error log: {log_demo!r}")

            # trek.bas smoke (last): full game can leave gfx state; run after all pixel tests.
            if not TREK_BAS.is_file():
                browser.close()
                raise RuntimeError(f"missing {TREK_BAS}")
            trek_src = TREK_BAS.read_text(encoding="utf-8")
            page.wait_for_function(
                "() => !document.getElementById('run').disabled",
                timeout=60000,
            )
            page.fill("#program", trek_src)
            _click_run(page)
            time.sleep(2.5)
            page.evaluate("() => { if (window.Module) Module.wasmStopRequested = 1; }")
            page.wait_for_function(
                "() => (window.Module && Module.wasmGfxRunDone === 1)",
                timeout=180000,
            )
            log_trek = page.text_content("#log") or ""
            if log_trek.strip():
                browser.close()
                raise RuntimeError(f"trek.bas smoke error log: {log_trek!r}")

            browser.close()
    finally:
        httpd.shutdown()
        httpd.server_close()

    print("wasm_browser_canvas_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
