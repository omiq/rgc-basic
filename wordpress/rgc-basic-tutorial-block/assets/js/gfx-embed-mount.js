/**
 * RGC-BASIC raylib WASM embed for WordPress (one iframe per mount).
 *
 * Swapped from canvas-WASM + shared-window.Module pattern to an
 * iframe-per-embed pointing at assets/raylib-embed.html. Each iframe runs
 * its own basic-raylib.* so the GFX block gets the full 2.1 feature set
 * (LOADMUSIC / LOADSOUND / SCROLL ZONE / SCROLL LINE / IMAGE DRAW) that
 * the frozen canvas WASM can't deliver.
 *
 * Parent (this file):
 *   - editor textarea + syntax highlight overlay
 *   - toolbar: Run / Pause / Resume / Stop / Zoom / Fullscreen
 *   - poster + deferred-load UI
 *   - optional VFS upload / download (via postMessage to iframe)
 *   - canvasMode styling on the iframe wrapper
 *   - autorun timer
 *
 * Iframe (assets/raylib-embed.html):
 *   - basic-raylib.js + basic-raylib.wasm
 *   - canvas + GLFW keyboard/mouse
 *   - miniaudio / raylib audio unlock badge
 *   - runtime error forwarding
 */
(function (global) {
  'use strict';

  function ensureTrailingSlash(url) {
    if (!url) return '';
    return url.slice(-1) === '/' ? url : url + '/';
  }

  function attachHighlightOverlay(ta) {
    if (global.RgcBasicHighlight && typeof global.RgcBasicHighlight.attach === 'function') {
      return global.RgcBasicHighlight.attach(ta);
    }
    return ta.parentNode;
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
   * @param {string} opts.wasmBaseUrl - URL to folder with basic-raylib.js + raylib-embed.html's parent dir (i.e. assets/wasm/ under the plugin). raylib-embed.html is resolved as "../raylib-embed.html".
   * @param {string} [opts.assetCacheBust]
   * @param {boolean} [opts.showVfsTools]
   * @param {string} [opts.interpreterFlags]
   * @param {boolean} [opts.autorun]
   * @param {string}  [opts.canvasMode] - "visible" | "offscreen" | "hidden"
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
    var autorun = opts.autorun === true;
    var canvasMode = typeof opts.canvasMode === 'string' ? opts.canvasMode : 'visible';

    if (!wasmBase) {
      return Promise.reject(new Error('RgcBasicGfxEmbed: wasmBaseUrl is required'));
    }

    /*
     * raylib-embed.html sits one level up from the wasm/ folder (both
     * under assets/). wasmBase ends in "assets/wasm/"; strip the trailing
     * "wasm/" to get "assets/". Custom bases that point somewhere else
     * still work as long as raylib-embed.html lives next to a wasm/
     * sibling folder.
     */
    var iframeSrcBase = wasmBase.replace(/wasm\/$/, '');
    var iframeSrc = iframeSrcBase + 'raylib-embed.html?cb=' + encodeURIComponent(assetCb);

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

    function btn(label) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      return b;
    }

    var runBtn = btn('Run');
    var pauseBtn = btn('Pause');
    var resumeBtn = btn('Resume');
    var stopBtn = btn('Stop');
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

    var fsBtn = btn('Fullscreen');

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

    /*
     * iframe runs basic-raylib — owns its canvas + GL context. Parent
     * only sizes/styles the wrapper and routes postMessages.
     */
    var iframe = document.createElement('iframe');
    iframe.className = 'rgc-basic-gfx-screen';
    iframe.title = 'RGC-BASIC raylib runtime';
    iframe.setAttribute('allow', 'autoplay; fullscreen');
    iframe.setAttribute('scrolling', 'no');
    iframe.style.border = '0';
    iframe.style.display = 'block';
    iframe.style.background = '#000';
    iframe.width = 320;
    iframe.height = 200;
    iframe.src = iframeSrc;
    canvasWrap.appendChild(iframe);

    if (canvasMode === 'offscreen') {
      canvasWrap.style.position = 'absolute';
      canvasWrap.style.left = '-9999px';
      canvasWrap.style.top = '0';
      canvasWrap.setAttribute('aria-hidden', 'true');
    } else if (canvasMode === 'hidden') {
      canvasWrap.style.display = 'none';
      canvasWrap.setAttribute('aria-hidden', 'true');
    }

    var logEl = document.createElement('div');
    logEl.className = 'rgc-basic-gfx-log';

    app.appendChild(ta);
    var editorWrap = attachHighlightOverlay(ta);
    if (!showEditor) {
      editorWrap.hidden = true;
      editorWrap.setAttribute('aria-hidden', 'true');
    }
    app.appendChild(toolbar);
    app.appendChild(vfsHost);
    app.appendChild(canvasWrap);
    app.appendChild(logEl);
    root.appendChild(app);

    var runtimeReady = false;
    var running = false;
    var pendingAutorun = false;

    function logErr(msg) {
      logEl.textContent = msg || '';
      logEl.style.display = msg && String(msg).length ? 'block' : 'none';
    }

    function applyZoom() {
      var z = parseInt(zoomEl.value, 10) || 2;
      iframe.style.width = (320 * z) + 'px';
      iframe.style.height = (200 * z) + 'px';
    }
    applyZoom();

    function post(msg) {
      if (!iframe.contentWindow) return;
      try { iframe.contentWindow.postMessage(msg, '*'); } catch (e) {}
    }

    function setControlsRunning(isRunning) {
      running = isRunning;
      if (showControls) {
        runBtn.disabled = isRunning;
        pauseBtn.disabled = !isRunning;
        resumeBtn.disabled = true;
        stopBtn.disabled = !isRunning;
      } else {
        runBtn.disabled = isRunning;
      }
    }

    function doRun() {
      if (!runtimeReady) {
        pendingAutorun = true;
        return;
      }
      logErr('');
      setControlsRunning(true);
      post({
        type: 'rgc-basic-run',
        source: ta.value,
        flags: flagsStr
      });
    }

    runBtn.onclick = doRun;

    if (showControls) {
      pauseBtn.onclick = function () {
        if (!running) return;
        post({ type: 'rgc-basic-pause' });
        pauseBtn.disabled = true;
        resumeBtn.disabled = false;
      };
      resumeBtn.onclick = function () {
        post({ type: 'rgc-basic-resume' });
        pauseBtn.disabled = false;
        resumeBtn.disabled = true;
      };
      stopBtn.onclick = function () {
        post({ type: 'rgc-basic-stop' });
      };
    }

    zoomEl.addEventListener('change', applyZoom);

    if (showFullscreen) {
      fsBtn.onclick = function () {
        var el = iframe;
        if (!document.fullscreenElement) {
          if (el.requestFullscreen) el.requestFullscreen().catch(function () {});
        } else {
          document.exitFullscreen();
        }
      };
    }

    /* VFS UI — upload pushes files into the iframe's MEMFS via postMessage;
     * download asks the iframe to read a path and streams bytes back out as
     * a browser file download. */
    var pendingVfsReads = Object.create(null);
    var vfsReadSeq = 1;

    if (showVfs) {
      var uploadBtn = document.createElement('button');
      uploadBtn.type = 'button';
      uploadBtn.textContent = 'Upload to VFS';
      var fileInput = document.createElement('input');
      fileInput.type = 'file';
      fileInput.multiple = true;
      fileInput.style.display = 'none';
      var pathInput = document.createElement('input');
      pathInput.type = 'text';
      pathInput.placeholder = '/out.txt';
      pathInput.size = 26;
      var downloadBtn = document.createElement('button');
      downloadBtn.type = 'button';
      downloadBtn.textContent = 'Download from VFS';

      uploadBtn.addEventListener('click', function () { fileInput.click(); });
      fileInput.addEventListener('change', function () {
        var files = fileInput.files ? Array.prototype.slice.call(fileInput.files) : [];
        files.forEach(function (f) {
          var fr = new FileReader();
          fr.onload = function () {
            var u8 = new Uint8Array(fr.result);
            var p = f.name;
            if (p.charAt(0) !== '/') p = '/' + p;
            post({ type: 'rgc-basic-vfs-write', path: p, bytes: u8 });
            logErr('Uploaded: ' + p);
          };
          fr.onerror = function () { logErr('Upload failed: ' + f.name); };
          fr.readAsArrayBuffer(f);
        });
        fileInput.value = '';
      });
      downloadBtn.addEventListener('click', function () {
        var raw = (pathInput.value || '/out.txt').trim();
        if (raw.charAt(0) !== '/') raw = '/' + raw;
        var reqId = 'vfs-' + (vfsReadSeq++);
        pendingVfsReads[reqId] = raw;
        post({ type: 'rgc-basic-vfs-read', path: raw, requestId: reqId });
      });

      vfsHost.appendChild(uploadBtn);
      vfsHost.appendChild(fileInput);
      vfsHost.appendChild(document.createTextNode(' '));
      vfsHost.appendChild(pathInput);
      vfsHost.appendChild(document.createTextNode(' '));
      vfsHost.appendChild(downloadBtn);
    }

    window.addEventListener('message', function (ev) {
      if (ev.source !== iframe.contentWindow) return;
      var d = ev.data;
      if (!d || !d.type) return;
      if (d.type === 'rgc-basic-status') {
        if (d.status === 'ready') {
          runtimeReady = true;
          if (pendingAutorun || autorun) {
            pendingAutorun = false;
            doRun();
          }
        } else if (d.status === 'running') {
          setControlsRunning(true);
        } else if (d.status === 'stopped') {
          setControlsRunning(false);
        } else if (d.status === 'error') {
          setControlsRunning(false);
          if (d.detail) logErr(String(d.detail));
        }
      }
      else if (d.type === 'rgc-basic-runtime-error') {
        var line = d.line ? ('line ' + d.line + ': ') : '';
        logErr(line + (d.message || 'Runtime error'));
      }
      else if (d.type === 'rgc-basic-vfs-read-result') {
        var cb = pendingVfsReads[d.requestId];
        if (!cb) return;
        delete pendingVfsReads[d.requestId];
        if (d.error) { logErr('Download failed: ' + d.error); return; }
        try {
          var bytes = d.bytes;
          if (!(bytes instanceof Uint8Array)) bytes = new Uint8Array(bytes);
          var blob = new Blob([bytes], { type: 'application/octet-stream' });
          var a = document.createElement('a');
          a.href = URL.createObjectURL(blob);
          a.download = (d.path || '/download.bin').split('/').pop() || 'download.bin';
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          setTimeout(function () { URL.revokeObjectURL(a.href); }, 2500);
          logErr('Downloaded: ' + d.path);
        } catch (e) {
          logErr('Download failed: ' + (e && e.message ? e.message : e));
        }
      }
      else if (d.type === 'rgc-basic-vfs-write-error') {
        logErr('Upload failed: ' + (d.message || 'unknown'));
      }
    });

    posterBtn.addEventListener('click', function () {
      if (posterLayer.parentNode) posterLayer.style.display = 'none';
      app.hidden = false;
      /* Deferred load: iframe hasn't been attached yet. appendChild
       * already happened via initial DOM setup, so the iframe is loading;
       * runtimeReady flag flips on the ready message. If user clicked Run
       * before runtime ready, pendingAutorun holds the request. */
      pendingAutorun = true;
      if (runtimeReady) doRun();
    });

    if (!deferLoad || !posterUrl) {
      if (posterUrl) {
        posterLayer.style.display = 'none';
        app.hidden = false;
      }
      /* autorun: mark intent; the ready postMessage will fire doRun(). */
      if (autorun) pendingAutorun = true;
    }

    return Promise.resolve({
      container: root,
      iframe: iframe,
      run: doRun,
      stop: function () { post({ type: 'rgc-basic-stop' }); },
      pause: function () { post({ type: 'rgc-basic-pause' }); },
      resume: function () { post({ type: 'rgc-basic-resume' }); },
      setProgram: function (src) { ta.value = src; }
    });
  }

  global.RgcBasicGfxEmbed = { mount: mount };
})(typeof window !== 'undefined' ? window : this);
