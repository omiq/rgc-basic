/**
 * RGC-BASIC canvas WASM embed for WordPress (one instance per mount).
 * Depends: vfs-helpers.js (optional, for VFS UI).
 * Loads: basic-canvas.js + basic-canvas.wasm from opts.wasmBaseUrl
 */
(function (global) {
  'use strict';

  /*
   * basic-canvas.js is a non-MODULARIZE'd Emscripten build: there is exactly
   * ONE WASM runtime per page. Every mount() shares the same window.Module.
   *
   * Per-mount state (program source, flags, canvas, callbacks) is swapped in
   * by whichever embed currently "owns" the runtime. Only the active owner's
   * rAF loop blits to its canvas — idle embeds freeze at their last frame.
   */
  var canvasJsPromise = null;
  var sharedRuntime = {
    initPromise: null,
    Module: null,          // the live window.Module once runtime is initialised
    activeMount: null,     // id of the mount currently running (or null)
    currentRun: null       // promise for the in-flight basic_load_and_run_gfx call
  };
  var mountIdSeq = 0;

  function ensureTrailingSlash(url) {
    if (!url) return '';
    return url.slice(-1) === '/' ? url : url + '/';
  }

  function loadScriptOnce(src) {
    if (canvasJsPromise) return canvasJsPromise;
    canvasJsPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src;
      s.async = false;
      s.onload = function () { resolve(); };
      s.onerror = function () { reject(new Error('Failed to load ' + src)); };
      document.head.appendChild(s);
    });
    return canvasJsPromise;
  }

  /**
   * Initialise the shared Emscripten runtime exactly once. All mounts share
   * the same window.Module; per-mount callbacks are swapped on claim.
   */
  function ensureRuntime(wasmBase, assetCb) {
    if (sharedRuntime.initPromise) return sharedRuntime.initPromise;
    sharedRuntime.initPromise = new Promise(function (resolve, reject) {
      window.Module = {
        canvasAssetCb: assetCb,
        locateFile: function (p) {
          if (p.endsWith('.wasm')) {
            return wasmBase + 'basic-canvas.wasm?cb=' + encodeURIComponent(assetCb);
          }
          return wasmBase + p;
        },
        onRuntimeInitialized: function () {
          sharedRuntime.Module = window.Module;
          resolve(sharedRuntime.Module);
        }
      };
      var jsUrl = wasmBase + 'basic-canvas.js?cb=' + encodeURIComponent(assetCb);
      loadScriptOnce(jsUrl).catch(reject);
    });
    return sharedRuntime.initPromise;
  }

  /* ------------------------------------------------------------------ *
   *  Syntax highlighting — delegated to the shared basic-highlight.js
   *  module (window.RgcBasicHighlight). Kept as a thin wrapper so mount()
   *  can still call attachHighlightOverlay(ta) and fall back gracefully
   *  if the shared module failed to load.
   * ------------------------------------------------------------------ */
  function attachHighlightOverlay(ta) {
    if (global.RgcBasicHighlight && typeof global.RgcBasicHighlight.attach === 'function') {
      return global.RgcBasicHighlight.attach(ta);
    }
    return ta.parentNode; // fallback: leave textarea as-is
  }

  function numPtr(p) {
    if (p == null) return 0;
    if (typeof p === 'bigint') return Number(p);
    return Number(p);
  }

  /**
   * @param {HTMLElement} container
   * @param {object} opts
   * @param {string} opts.program
   * @param {boolean} [opts.showEditor]
   * @param {boolean} [opts.showControls]
   * @param {boolean} [opts.showFullscreen]
   * @param {string} [opts.posterImageUrl]
   * @param {boolean} [opts.deferLoad] - load WASM on first Run (default true if poster)
   * @param {string} opts.wasmBaseUrl - URL to folder with basic-canvas.js
   * @param {string} [opts.assetCacheBust]
   * @param {boolean} [opts.showVfsTools]
   * @param {string} [opts.interpreterFlags] - e.g. "-petscii -charset lower"
   */
  function mount(container, opts) {
    opts = opts || {};
    var program = typeof opts.program === 'string' ? opts.program : '10 END\n';
    var showEditor = opts.showEditor !== false;
    var showControls = opts.showControls !== false;
    var showFullscreen = opts.showFullscreen !== false;
    var posterUrl = (opts.posterImageUrl && String(opts.posterImageUrl).trim()) || '';
    var deferLoad = opts.deferLoad !== false && !!posterUrl;
    var wasmBase = ensureTrailingSlash(opts.wasmBaseUrl || '');
    var assetCb = opts.assetCacheBust || String(Date.now());
    var showVfs = opts.showVfsTools !== false;
    var flagsStr = typeof opts.interpreterFlags === 'string' ? opts.interpreterFlags : '-petscii -charset lower -palette ansi -columns 40';

    if (!wasmBase) {
      return Promise.reject(new Error('RgcBasicGfxEmbed: wasmBaseUrl is required'));
    }

    var root = document.createElement('div');
    root.className = 'rgc-basic-gfx-embed';
    container.appendChild(root);

    var posterLayer = document.createElement('div');
    posterLayer.className = 'rgc-basic-gfx-poster';
    var posterImg = document.createElement('img');
    posterImg.className = 'rgc-basic-gfx-poster-img';
    posterImg.alt = '';
    var posterBtn = document.createElement('button');
    posterBtn.type = 'button';
    posterBtn.className = 'rgc-basic-gfx-run-poster';
    posterBtn.textContent = 'Run';

    if (posterUrl) {
      posterImg.src = posterUrl;
      posterLayer.appendChild(posterImg);
      posterLayer.appendChild(posterBtn);
      root.appendChild(posterLayer);
    }

    var app = document.createElement('div');
    app.className = 'rgc-basic-gfx-app';
    if (posterUrl && deferLoad) {
      app.hidden = true;
    }

    var ta = document.createElement('textarea');
    ta.className = 'rgc-basic-gfx-program';
    ta.spellcheck = false;
    ta.value = program;
    if (!showEditor) {
      ta.hidden = true;
      ta.setAttribute('aria-hidden', 'true');
    }

    var toolbar = document.createElement('div');
    toolbar.className = 'rgc-basic-gfx-toolbar';
    if (!showControls) {
      toolbar.classList.add('rgc-basic-gfx-toolbar--minimal');
    }

    function btn(label, id) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      if (id) b.id = id;
      return b;
    }

    var runBtn = btn('Run', '');
    var pauseBtn = btn('Pause', '');
    var resumeBtn = btn('Resume', '');
    var stopBtn = btn('Stop', '');
    pauseBtn.disabled = true;
    resumeBtn.disabled = true;
    stopBtn.disabled = true;

    var zoomEl = document.createElement('select');
    zoomEl.className = 'rgc-basic-gfx-zoom';
    ;[['1', '1x'], ['2', '2x'], ['3', '3x'], ['4', '4x']].forEach(function (z) {
      var o = document.createElement('option');
      o.value = z[0];
      o.textContent = z[1];
      if (z[0] === '2') o.selected = true;
      zoomEl.appendChild(o);
    });

    var fsBtn = btn('Fullscreen', '');

    toolbar.appendChild(runBtn);
    if (showControls) {
      toolbar.appendChild(pauseBtn);
      toolbar.appendChild(resumeBtn);
      toolbar.appendChild(stopBtn);
      toolbar.appendChild(document.createTextNode(' Zoom '));
      toolbar.appendChild(zoomEl);
    }
    if (showFullscreen) {
      toolbar.appendChild(fsBtn);
    }

    var vfsHost = document.createElement('div');
    vfsHost.className = 'rgc-basic-gfx-vfs';
    if (!showVfs) {
      vfsHost.style.display = 'none';
    }

    var canvasWrap = document.createElement('div');
    canvasWrap.className = 'rgc-basic-gfx-canvas-wrap';

    var canvas = document.createElement('canvas');
    canvas.className = 'rgc-basic-gfx-screen';
    canvas.width = 320;
    canvas.height = 200;
    canvas.tabIndex = 0;
    canvas.title = 'Click for keyboard input';
    canvasWrap.appendChild(canvas);

    var inputRow = document.createElement('div');
    inputRow.className = 'rgc-basic-gfx-input-row';
    inputRow.style.display = 'none';
    var inputLine = document.createElement('input');
    inputLine.type = 'text';
    inputLine.className = 'rgc-basic-gfx-input-line';
    inputLine.autocomplete = 'off';
    inputRow.appendChild(document.createTextNode('INPUT '));
    inputRow.appendChild(inputLine);

    var logEl = document.createElement('div');
    logEl.className = 'rgc-basic-gfx-log';

    app.appendChild(ta);
    // Wrap the textarea in a syntax-highlighting overlay. The wrapper
    // replaces the textarea in the DOM so subsequent .appendChild of the
    // toolbar still appears after the editor.
    var editorWrap = attachHighlightOverlay(ta);
    if (!showEditor) {
      editorWrap.hidden = true;
      editorWrap.setAttribute('aria-hidden', 'true');
    }
    app.appendChild(toolbar);
    app.appendChild(vfsHost);
    app.appendChild(canvasWrap);
    app.appendChild(inputRow);
    app.appendChild(logEl);
    root.appendChild(app);

    var ctx = canvas.getContext('2d', { alpha: false });
    var img = ctx.createImageData(320, 200);
    var wasmRunPending = false;
    var lastRgbaVer = 0;
    var copyFailLogged = false;
    var Module = null;
    var mountId = ++mountIdSeq;

    function isActive() {
      return sharedRuntime.activeMount === mountId;
    }

    var C64_PALETTE_RGB = [
      [0, 0, 0], [255, 255, 255], [136, 0, 0], [170, 255, 238],
      [204, 68, 204], [0, 204, 85], [0, 0, 170], [238, 238, 119],
      [221, 136, 85], [102, 68, 0], [255, 119, 119], [51, 51, 51],
      [119, 119, 119], [170, 255, 102], [0, 136, 255], [187, 187, 187]
    ];

    function logErr(msg) {
      logEl.textContent = msg || '';
      logEl.style.display = msg && String(msg).length ? 'block' : 'none';
    }

    /**
     * Paint a "Loading..." splash on the canvas so the user has visual
     * feedback between clicking Run and the first WASM frame appearing.
     * The rAF loop (frame()) will overwrite this as soon as the program
     * starts producing output.
     */
    function drawLoadingSplash() {
      try {
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#7ee787';
        ctx.font = 'bold 18px ui-monospace, Menlo, Consolas, monospace';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('Loading\u2026', canvas.width / 2, canvas.height / 2);
      } catch (e) { /* non-fatal */ }
    }

    function wasmMemoryBuffer() {
      var M = window.Module;
      if (!M) return null;
      if (M.wasmMemory && M.wasmMemory.buffer) return M.wasmMemory.buffer;
      if (M.asm && M.asm.memory && M.asm.memory.buffer) return M.asm.memory.buffer;
      if (M.HEAPU8 && M.HEAPU8.buffer) return M.HEAPU8.buffer;
      if (M.HEAP8 && M.HEAP8.buffer) return M.HEAP8.buffer;
      return null;
    }

    function heapU8() {
      var M = window.Module;
      return M ? (M.HEAPU8 || M['HEAPU8'] || null) : null;
    }

    function applyZoom() {
      var z = parseInt(zoomEl.value, 10) || 2;
      canvas.style.width = canvas.width * z + 'px';
      canvas.style.height = canvas.height * z + 'px';
    }

    function copyRgbaFromWasm() {
      var M = Module;
      if (!M || !M._wasm_gfx_rgba_ptr) {
        if (!copyFailLogged) {
          copyFailLogged = true;
          logErr('Canvas: rebuild basic-wasm-canvas and hard-refresh.');
        }
        return false;
      }
      var ptr = numPtr(M._wasm_gfx_rgba_ptr());
      var buf = wasmMemoryBuffer();
      var w = M.wasmGfxFbW || 320;
      var h = M.wasmGfxFbH || 200;
      var need = w * h * 4;
      var hu = heapU8();
      var u8 = null;
      if (buf && ptr >= 0 && ptr + need <= buf.byteLength) {
        try {
          u8 = new Uint8Array(buf, ptr, need);
        } catch (e) {
          u8 = null;
        }
      }
      if (!u8 && hu && ptr >= 0 && ptr + need <= hu.length) {
        u8 = hu.subarray(ptr, ptr + need);
      }
      if (!u8) return false;
      var borderPx = typeof M.wasmGfxBorderPx === 'number' && M.wasmGfxBorderPx > 0 ? M.wasmGfxBorderPx | 0 : 0;
      if (borderPx > 256) borderPx = 256;
      var bci = typeof M.wasmGfxBorderColorIdx === 'number' ? M.wasmGfxBorderColorIdx : -1;
      var bgIdx = typeof M.wasmGfxContentBgIdx === 'number' ? M.wasmGfxContentBgIdx & 15 : 0;
      var borderIdx = bci >= 0 && bci <= 15 ? bci & 15 : bgIdx;
      var brgb = C64_PALETTE_RGB[borderIdx] || C64_PALETTE_RGB[0];
      var cw = w + 2 * borderPx;
      var ch = h + 2 * borderPx;
      if (canvas.width !== cw || canvas.height !== ch) {
        canvas.width = cw;
        canvas.height = ch;
        img = null;
      }
      ctx.fillStyle = 'rgb(' + brgb[0] + ',' + brgb[1] + ',' + brgb[2] + ')';
      ctx.fillRect(0, 0, cw, ch);
      if (!img || img.width !== w || img.height !== h) {
        img = ctx.createImageData(w, h);
      }
      img.data.set(u8);
      ctx.putImageData(img, borderPx, borderPx);
      return true;
    }

    function frame() {
      requestAnimationFrame(frame);
      // Only the active mount blits — idle embeds freeze at their last frame
      // so a running embed can't stomp on another embed's canvas.
      if (!isActive()) return;
      if (!wasmRunPending || !Module || !Module._wasm_gfx_rgba_version_read) return;
      if (typeof Module.rgcPollMouseForWasm === 'function') {
        Module.rgcPollMouseForWasm();
      }
      var ver = numPtr(Module._wasm_gfx_rgba_version_read());
      if (ver !== lastRgbaVer) {
        lastRgbaVer = ver;
        copyRgbaFromWasm();
      }
    }
    requestAnimationFrame(frame);

    /*
     * Swap the runtime's per-run callbacks to point at THIS mount. Called
     * when this mount claims ownership of the shared runtime (on Run click).
     */
    function claimRuntime() {
      sharedRuntime.activeMount = mountId;
      Module.printErr = function (t) {
        var s = String(t);
        if (logEl.textContent && logEl.textContent.length) {
          logEl.textContent = logEl.textContent + '\n' + s;
        } else {
          logErr(s);
        }
      };
      Module.onWasmNeedInputLine = function () {
        inputRow.style.display = 'flex';
        inputLine.value = '';
        inputLine.focus();
      };
      Module.onAbort = function (what) {
        logErr('WASM aborted: ' + (what || 'unknown'));
        wasmRunPending = false;
        runBtn.disabled = false;
        if (showControls) {
          pauseBtn.disabled = true;
          resumeBtn.disabled = true;
          stopBtn.disabled = true;
        }
        Module.wasmPaused = 0;
      };
    }

    function doRun() {
      // Stale callbacks from another embed must be replaced before we touch Module.
      claimRuntime();
      logErr('');
      copyFailLogged = false;
      inputRow.style.display = 'none';
      Module.wasmStopRequested = 0;
      Module.wasmPaused = 0;
      wasmRunPending = true;
      lastRgbaVer = -1;
      runBtn.disabled = true;
      if (showControls) {
        pauseBtn.disabled = false;
        resumeBtn.disabled = true;
        stopBtn.disabled = false;
      }
      var rc = Module.ccall('basic_apply_arg_string', 'number', ['string'], [flagsStr]);
      if (rc !== 0) {
        logErr('Invalid interpreter options.');
        wasmRunPending = false;
        runBtn.disabled = false;
        return Promise.resolve();
      }
      Module.FS.writeFile('/program.bas', ta.value);
      if (Module._wasm_gfx_key_state_ptr && Module.HEAPU8) {
        var kp = Module._wasm_gfx_key_state_ptr();
        if (kp) Module.HEAPU8.fill(0, kp, kp + 256);
      } else if (Module._wasm_gfx_key_state_clear) {
        Module.ccall('wasm_gfx_key_state_clear', null, [], []);
      }
      canvas.focus();
      if (Module._wasm_gfx_init_video_for_run) {
        Module.ccall('wasm_gfx_init_video_for_run', null, [], []);
      }
      var runP = Module.ccall('basic_load_and_run_gfx', null, ['string'], ['/program.bas'], { async: true })
        .catch(function (e) {
          logErr(String(e && e.message ? e.message : e));
        })
        .finally(function () {
          wasmRunPending = false;
          Module.wasmPaused = 0;
          runBtn.disabled = false;
          if (showControls) {
            pauseBtn.disabled = true;
            resumeBtn.disabled = true;
            stopBtn.disabled = true;
          }
          copyRgbaFromWasm();
          if (sharedRuntime.currentRun === runP) {
            sharedRuntime.currentRun = null;
          }
        });
      sharedRuntime.currentRun = runP;
      return runP;
    }

    function wireRunHandlers() {
      Module = sharedRuntime.Module || window.Module;
      runBtn.onclick = function () {
        // Only one WASM instance per page. If another embed is currently
        // running, ask it to stop and wait for it to finish before we start.
        var prev = sharedRuntime.currentRun;
        if (prev) {
          if (Module) Module.wasmStopRequested = 1;
          Promise.resolve(prev).then(doRun).catch(function () { doRun(); });
        } else {
          doRun();
        }
      };

      if (showControls) {
        pauseBtn.onclick = function () {
          if (!isActive()) return;
          Module.wasmPaused = 1;
          pauseBtn.disabled = true;
          resumeBtn.disabled = false;
        };
        resumeBtn.onclick = function () {
          if (!isActive()) return;
          Module.wasmPaused = 0;
          pauseBtn.disabled = false;
          resumeBtn.disabled = true;
        };
        stopBtn.onclick = function () {
          if (!isActive()) return;
          Module.wasmStopRequested = 1;
          Module.wasmPaused = 0;
        };
      }

      zoomEl.addEventListener('change', applyZoom);

      if (showFullscreen) {
        fsBtn.onclick = function () {
          if (!document.fullscreenElement) {
            canvasWrap.requestFullscreen().catch(function () {});
          } else {
            document.exitFullscreen();
          }
        };
      }

      // Module.printErr / onWasmNeedInputLine / onAbort are assigned in
      // claimRuntime() on each Run click so that each embed's callbacks
      // route to its own log/input UI.

      if (typeof RgcVfsHelpers !== 'undefined' && showVfs) {
        RgcVfsHelpers.vfsMountUI(vfsHost, Module, {
          pathDefault: '/out.txt',
          onStatus: function (msg) {
            logErr(msg);
          }
        });
      }

      /* Mouse → wasm_mouse_js_frame (same contract as web/canvas.html). */
      (function setupGfxEmbedMouse() {
        var RAYLIB_TO_CSS = ['auto', 'default', 'text', 'wait', 'crosshair', 'pointer', 'nwse-resize',
          'nesw-resize', 'ew-resize', 'ns-resize', 'move', 'not-allowed', 'progress'];
        var lastMouseClientX = 0;
        var lastMouseClientY = 0;
        var lastMouseButtons = 0;
        Module._rgcMouseWarpHold = 0;
        Module._rgcMouseWarpX = 0;
        Module._rgcMouseWarpY = 0;
        Module._rgcMouseCursorHidden = false;
        Module.rgcMouseWarp = function (cx, cy) {
          Module._rgcMouseWarpX = cx | 0;
          Module._rgcMouseWarpY = cy | 0;
          Module._rgcMouseWarpHold = 4;
        };
        Module.rgcMouseSetCursor = function (code) {
          if (Module._rgcMouseCursorHidden) return;
          var c = code | 0;
          var css = (c >= 0 && c < RAYLIB_TO_CSS.length) ? RAYLIB_TO_CSS[c] : 'default';
          canvas.style.cursor = css;
        };
        Module.rgcMouseHideCursor = function () {
          Module._rgcMouseCursorHidden = true;
          canvas.style.cursor = 'none';
        };
        Module.rgcMouseShowCursor = function () {
          Module._rgcMouseCursorHidden = false;
          canvas.style.cursor = 'text';
        };
        Module.rgcPollMouseForWasm = function () {
          if (!Module._wasm_mouse_js_frame) return;
          var fbW = (typeof Module.wasmGfxFbW === 'number' && Module.wasmGfxFbW > 0) ? (Module.wasmGfxFbW | 0) : 320;
          var fbH = (typeof Module.wasmGfxFbH === 'number' && Module.wasmGfxFbH > 0) ? (Module.wasmGfxFbH | 0) : 200;
          var borderPx = (typeof Module.wasmGfxBorderPx === 'number' && Module.wasmGfxBorderPx > 0) ? (Module.wasmGfxBorderPx | 0) : 0;
          var mx, my, bl, br, bm;
          if (Module._rgcMouseWarpHold > 0) {
            Module._rgcMouseWarpHold--;
            mx = Module._rgcMouseWarpX;
            my = Module._rgcMouseWarpY;
          } else {
            var rect = canvas.getBoundingClientRect();
            var scaleX = canvas.width > 0 ? (canvas.width / rect.width) : 1;
            var scaleY = canvas.height > 0 ? (canvas.height / rect.height) : 1;
            var px = (lastMouseClientX - rect.left) * scaleX;
            var py = (lastMouseClientY - rect.top) * scaleY;
            mx = Math.floor(px - borderPx + 1e-6);
            my = Math.floor(py - borderPx + 1e-6);
          }
          if (mx < 0) mx = 0;
          if (my < 0) my = 0;
          if (mx > fbW - 1) mx = fbW - 1;
          if (my > fbH - 1) my = fbH - 1;
          bl = lastMouseButtons & 1 ? 1 : 0;
          br = lastMouseButtons & 2 ? 1 : 0;
          bm = lastMouseButtons & 4 ? 1 : 0;
          Module.ccall('wasm_mouse_js_frame', null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [mx, my, bl, br, bm, fbW, fbH]);
        };
        window.addEventListener('mousemove', function (ev) {
          lastMouseClientX = ev.clientX;
          lastMouseClientY = ev.clientY;
        }, true);
        window.addEventListener('mousedown', function (ev) {
          lastMouseClientX = ev.clientX;
          lastMouseClientY = ev.clientY;
          if (ev.button === 0) lastMouseButtons |= 1;
          else if (ev.button === 2) lastMouseButtons |= 2;
          else if (ev.button === 1) lastMouseButtons |= 4;
        }, true);
        window.addEventListener('mouseup', function (ev) {
          lastMouseClientX = ev.clientX;
          lastMouseClientY = ev.clientY;
          if (ev.button === 0) lastMouseButtons &= ~1;
          else if (ev.button === 2) lastMouseButtons &= ~2;
          else if (ev.button === 1) lastMouseButtons &= ~4;
        }, true);
        window.addEventListener('blur', function () { lastMouseButtons = 0; });
      })();

      function wasmGfxKeyIndex(ev) {
        var k = ev.key;
        if (k === 'Escape') return 27;
        if (k === 'Enter') return 13;
        if (k === ' ' || k === 'Spacebar') return 32;
        if (k === 'ArrowUp') return 145;
        if (k === 'ArrowDown') return 17;
        if (k === 'ArrowLeft') return 157;
        if (k === 'ArrowRight') return 29;
        if (k === 'Tab') return 9;
        if (k.length === 1) {
          var c = k.charCodeAt(0);
          if (c >= 97 && c <= 122) c -= 32;
          if (c >= 32 && c <= 126) return c;
        }
        return -1;
      }
      function wasmGfxKeyStateSync(ev, down) {
        if (inputRow.style.display === 'flex') return;
        var idx = wasmGfxKeyIndex(ev);
        if (idx < 0 || idx >= 256) return;
        var base = typeof Module._wasm_gfx_key_state_ptr === 'function' ? Module._wasm_gfx_key_state_ptr() : 0;
        if (base && Module.HEAPU8) {
          Module.HEAPU8[base + idx] = down ? 1 : 0;
        } else if (Module._wasm_gfx_key_state_set) {
          Module.ccall('wasm_gfx_key_state_set', null, ['number', 'number'], [idx, down ? 1 : 0]);
        }
      }
      canvas.addEventListener(
        'keydown',
        function (ev) {
          if (inputRow.style.display === 'flex') return;
          ev.preventDefault();
          wasmGfxKeyStateSync(ev, true);
          var code = ev.keyCode || ev.which;
          if (code === 13) Module.ccall('wasm_push_key', null, ['number'], [13]);
          else if (ev.key && ev.key.length === 1) {
            Module.ccall('wasm_push_key', null, ['number'], [ev.key.charCodeAt(0) & 0xff]);
          }
        },
        true
      );
      canvas.addEventListener('keyup', function (ev) {
        wasmGfxKeyStateSync(ev, false);
      }, true);

      inputLine.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter') {
          ev.preventDefault();
          Module.wasmInputLineText = inputLine.value;
          Module.wasmInputLineReady = 1;
          inputRow.style.display = 'none';
          canvas.focus();
        }
      });

      runBtn.disabled = false;
      applyZoom();
      copyRgbaFromWasm();
    }

    var handlersWired = false;
    /*
     * Per-mount init: await the shared runtime singleton, then wire THIS
     * mount's Run/Pause/Stop handlers. Called from posterBtn click (deferred
     * load) or eagerly on mount when there's no poster.
     */
    function initModule() {
      return ensureRuntime(wasmBase, assetCb).then(function (M) {
        Module = M;
        if (!handlersWired) {
          handlersWired = true;
          try {
            wireRunHandlers();
          } catch (e) {
            handlersWired = false;
            throw e;
          }
        }
      });
    }

    function revealAppAndRun() {
      if (posterLayer.parentNode) {
        posterLayer.style.display = 'none';
      }
      app.hidden = false;
      // Paint the loading splash immediately so the canvas isn't a blank
      // black rectangle while the WASM runtime is being fetched / compiled.
      drawLoadingSplash();
      return initModule().then(function () {
        // Runtime is ready and handlers are wired — now clicking Run actually runs.
        runBtn.click();
      });
    }

    posterBtn.addEventListener('click', function () {
      revealAppAndRun().catch(function (e) {
        logErr(String(e && e.message ? e.message : e));
        app.hidden = false;
      });
    });

    if (!deferLoad || !posterUrl) {
      drawLoadingSplash();
      initModule().then(function () {
        if (posterUrl) {
          posterLayer.style.display = 'none';
          app.hidden = false;
        }
      });
    }

    return Promise.resolve({
      container: root,
      getProgram: function () {
        return ta.value;
      },
      setProgram: function (s) {
        ta.value = s;
      }
    });
  }

  global.RgcBasicGfxEmbed = {
    mount: mount
  };
})(typeof window !== 'undefined' ? window : this);
