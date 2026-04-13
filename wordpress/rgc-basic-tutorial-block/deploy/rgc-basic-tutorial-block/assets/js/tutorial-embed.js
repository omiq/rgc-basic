/**
 * RGC-BASIC (Retro Game Coders BASIC) tutorial embeds: multiple terminal-style WASM instances on one page.
 * Requires: basic-modular.js + basic-modular.wasm (make basic-wasm-modular).
 *
 *   RgcBasicTutorialEmbed.mount(container, options).then(function(api) { ... });
 *
 * See docs/tutorial-embedding.md
 */
(function (global) {
  'use strict';

  var modularScriptPromise = null;
  var vfsHelpersPromise = null;

  function ensureTrailingSlash(url) {
    if (!url) return '';
    return url.slice(-1) === '/' ? url : url + '/';
  }

  function resolveBaseUrl(opts) {
    if (opts && opts.baseUrl) {
      return ensureTrailingSlash(opts.baseUrl);
    }
    if (typeof document !== 'undefined' && document.currentScript && document.currentScript.src) {
      return ensureTrailingSlash(document.currentScript.src.replace(/[^/]+$/, ''));
    }
    return '';
  }

  function escHtml(t) {
    return String(t)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function ansiToHtmlChunk(s) {
    var fg = null;
    var bg = null;
    var bold = false;
    var out = '';
    var re = /\x1b\[([0-9;]*)m/g;
    var last = 0;
    var m;
    function styleFor() {
      var st = '';
      if (fg !== null) st += 'color:' + fg + ';';
      if (bg !== null) st += 'background-color:' + bg + ';';
      if (bold) st += 'font-weight:bold;';
      return st;
    }
    function applyCode(n) {
      if (n === 0 || n === 22) {
        fg = null;
        bg = null;
        bold = false;
        return;
      }
      if (n === 1) {
        bold = true;
        return;
      }
      if (n === 39) {
        fg = null;
        return;
      }
      if (n === 49) {
        bg = null;
        return;
      }
      var ansi = {
        30: '#000',
        31: '#cd3131',
        32: '#0dbc79',
        33: '#e5e510',
        34: '#2472c8',
        35: '#bc3fbc',
        36: '#11a8cd',
        37: '#e5e5e5',
        90: '#666',
        91: '#f14c4c',
        92: '#23d18b',
        93: '#f5f543',
        94: '#3b8eea',
        95: '#d670d6',
        96: '#29b8db',
        97: '#ffffff'
      };
      var ansiBg = {
        40: '#000',
        41: '#cd3131',
        42: '#0dbc79',
        43: '#e5e510',
        44: '#2472c8',
        45: '#bc3fbc',
        46: '#11a8cd',
        47: '#e5e5e5',
        100: '#666',
        101: '#f14c4c',
        102: '#23d18b',
        103: '#f5f543',
        104: '#3b8eea',
        105: '#d670d6',
        106: '#29b8db',
        107: '#ffffff'
      };
      if (ansi[n]) fg = ansi[n];
      else if (ansiBg[n]) bg = ansiBg[n];
    }
    while ((m = re.exec(s)) !== null) {
      var plain = s.slice(last, m.index);
      if (plain.length) {
        var st0 = styleFor();
        out += st0 ? '<span style="' + st0 + '">' + escHtml(plain) + '</span>' : escHtml(plain);
      }
      last = m.index + m[0].length;
      var parts = m[1] === '' ? ['0'] : m[1].split(';');
      for (var i = 0; i < parts.length; i++) {
        var num = parseInt(parts[i], 10);
        if (isNaN(num)) num = 0;
        applyCode(num);
      }
    }
    var tail = s.slice(last);
    if (tail.length) {
      var st1 = styleFor();
      out += st1 ? '<span style="' + st1 + '">' + escHtml(tail) + '</span>' : escHtml(tail);
    }
    return out;
  }

  function loadCreateBasicModular(baseUrl, modularFile) {
    var name = modularFile || 'basic-modular.js';
    if (global.createBasicModular && typeof global.createBasicModular === 'function') {
      return Promise.resolve(global.createBasicModular);
    }
    if (modularScriptPromise) {
      return modularScriptPromise;
    }
    modularScriptPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = baseUrl + name;
      s.async = true;
      s.onload = function () {
        if (typeof global.createBasicModular === 'function') {
          resolve(global.createBasicModular);
        } else {
          reject(new Error('createBasicModular not defined after loading ' + name));
        }
      };
      s.onerror = function () {
        reject(new Error('Failed to load ' + baseUrl + name));
      };
      document.head.appendChild(s);
    });
    return modularScriptPromise;
  }

  function loadVfsHelpers(baseUrl) {
    if (global.RgcVfsHelpers || global.CbmVfsHelpers) {
      return Promise.resolve();
    }
    if (vfsHelpersPromise) {
      return vfsHelpersPromise;
    }
    vfsHelpersPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = baseUrl + 'vfs-helpers.js';
      s.async = true;
      s.onload = function () {
        if (global.RgcVfsHelpers) {
          resolve();
        } else {
          reject(new Error('RgcVfsHelpers missing after vfs-helpers.js'));
        }
      };
      s.onerror = function () {
        reject(new Error('Failed to load ' + baseUrl + 'vfs-helpers.js'));
      };
      document.head.appendChild(s);
    });
    return vfsHelpersPromise;
  }

  /**
   * @param {HTMLElement} container
   * @param {object} [opts]
   * @param {string} [opts.baseUrl] - directory ending in / containing basic-modular.js and .wasm
   * @param {string} [opts.modularScript='basic-modular.js']
   * @param {string} [opts.wasmFile='basic-modular.wasm']
   * @param {string} [opts.program] - initial editor text
   * @param {string} [opts.flags='-petscii -palette ansi -charset upper'] - passed to basic_apply_arg_string
   * @param {boolean} [opts.showEditor=true]
   * @param {boolean} [opts.showPauseStop=true]
   * @param {boolean} [opts.showVfsTools=true] - Upload/Download virtual FS (needs vfs-helpers.js beside basic-modular.js)
   * @param {boolean} [opts.runOnEdit=false] - After edits, auto-run after a short debounce (handy for tutorials)
   * @param {number} [opts.runOnEditMs=600] - Debounce delay for runOnEdit
   * @param {boolean} [opts.scrollToError=true] - After a run, scroll the output into view if stderr reported an error
   * @returns {Promise<{ run: function, resetOutput: function, destroy: function, getModule: function }>}
   */
  function mount(container, opts) {
    opts = opts || {};
    var baseUrl = resolveBaseUrl(opts);
    var wasmName = opts.wasmFile || 'basic-modular.wasm';
    var programDefault =
      opts.program != null
        ? opts.program
        : '10 PRINT "HELLO"\n20 END\n';
    var flags = opts.flags != null ? opts.flags : '-petscii -palette ansi -charset upper';
    var showEditor = opts.showEditor !== false;
    var showPauseStop = opts.showPauseStop !== false;
    var showVfsTools = opts.showVfsTools !== false;
    var runOnEdit = opts.runOnEdit === true;
    var runOnEditMs =
      typeof opts.runOnEditMs === 'number' && opts.runOnEditMs >= 0 ? opts.runOnEditMs : 600;
    var runOnEditTimer = null;
    var scrollToError = opts.scrollToError !== false;

    container.classList.add('rgc-tutorial-embed');
    container.innerHTML = '';

    var ta = document.createElement('textarea');
    ta.className = 'rgc-tutorial-program';
    ta.spellcheck = false;
    ta.value = programDefault;
    ta.style.width = '100%';
    ta.style.minHeight = opts.editorMinHeight || '120px';
    ta.style.fontFamily = 'ui-monospace, monospace';
    ta.style.fontSize = '13px';
    if (showEditor) {
      container.appendChild(ta);
    }

    var toolbar = document.createElement('div');
    toolbar.className = 'rgc-tutorial-toolbar';
    toolbar.style.marginTop = '0.5rem';

    var runBtn = document.createElement('button');
    runBtn.type = 'button';
    runBtn.textContent = 'Run';
    runBtn.disabled = true;
    toolbar.appendChild(runBtn);

    var pauseBtn = document.createElement('button');
    pauseBtn.type = 'button';
    pauseBtn.textContent = 'Pause';
    pauseBtn.disabled = true;
    var resumeBtn = document.createElement('button');
    resumeBtn.type = 'button';
    resumeBtn.textContent = 'Resume';
    resumeBtn.disabled = true;
    var stopBtn = document.createElement('button');
    stopBtn.type = 'button';
    stopBtn.textContent = 'Stop';
    stopBtn.disabled = true;
    if (showPauseStop) {
      toolbar.appendChild(pauseBtn);
      toolbar.appendChild(resumeBtn);
      toolbar.appendChild(stopBtn);
    }
    container.appendChild(toolbar);

    var vfsHost = document.createElement('div');
    vfsHost.className = 'rgc-tutorial-vfs';
    vfsHost.style.marginTop = '0.35rem';
    container.appendChild(vfsHost);

    var out = document.createElement('div');
    out.className = 'rgc-tutorial-output';
    out.tabIndex = 0;
    out.setAttribute('aria-live', 'polite');
    out.title = 'Click here, then type for GET / INKEY$';
    out.style.marginTop = '0.5rem';
    out.style.background = '#1e1e1e';
    out.style.color = '#d4d4d4';
    out.style.padding = '0.75rem';
    out.style.minHeight = opts.outputMinHeight || '100px';
    out.style.whiteSpace = 'pre-wrap';
    out.style.fontFamily = 'ui-monospace, monospace';
    out.style.fontSize = '13px';
    out.style.borderRadius = '4px';
    out.style.outline = 'none';
    container.appendChild(out);

    var inputRow = document.createElement('div');
    inputRow.className = 'rgc-tutorial-input-row';
    inputRow.style.display = 'none';
    inputRow.style.marginTop = '0.5rem';
    inputRow.style.alignItems = 'center';
    inputRow.style.gap = '0.5rem';
    var inputLabel = document.createElement('label');
    var inputLabelText = document.createElement('span');
    inputLabelText.textContent = 'INPUT';
    var inputLine = document.createElement('input');
    inputLine.type = 'text';
    inputLine.id = 'rgc-tut-in-' + Math.random().toString(36).slice(2, 9);
    inputLine.autocomplete = 'off';
    inputLine.spellcheck = false;
    inputLine.style.flex = '1';
    inputLine.style.fontFamily = 'ui-monospace, monospace';
    inputLabel.setAttribute('for', inputLine.id);
    inputLabel.style.display = 'flex';
    inputLabel.style.alignItems = 'center';
    inputLabel.style.gap = '0.35rem';
    inputLabel.style.flex = '1';
    inputLabel.appendChild(inputLabelText);
    inputLabel.appendChild(inputLine);
    inputRow.appendChild(inputLabel);
    container.appendChild(inputRow);

    var stdoutLineBuf = '';
    var stderrLineBuf = '';

    function appendOutputHtml(html, isError) {
      var span = document.createElement('span');
      span.innerHTML = html;
      out.appendChild(span);
      if (isError) out.dataset.error = '1';
    }

    function emitCompletedLine(line, isError) {
      appendOutputHtml(ansiToHtmlChunk(line), isError);
      appendOutputHtml('<br>', isError);
    }

    function writeStreamChunk(text, isError) {
      var buf = isError ? stderrLineBuf : stdoutLineBuf;
      buf += String(text);
      var parts = buf.split(/\r\n|\n|\r/);
      var tail = parts.pop();
      for (var i = 0; i < parts.length; i++) {
        emitCompletedLine(parts[i], isError);
      }
      if (isError) {
        stderrLineBuf = tail;
      } else {
        stdoutLineBuf = tail;
      }
    }

    function flushStreamTail(isError) {
      var buf = isError ? stderrLineBuf : stdoutLineBuf;
      if (buf.length) {
        appendOutputHtml(ansiToHtmlChunk(buf), isError);
        if (isError) stderrLineBuf = '';
        else stdoutLineBuf = '';
      }
    }

    function clearOutput() {
      out.innerHTML = '';
      delete out.dataset.error;
      stdoutLineBuf = '';
      stderrLineBuf = '';
    }

    var moduleRef = null;
    var destroyed = false;
    var vfsRemove = null;

    function pollWaitingKey() {
      if (destroyed || !moduleRef) return;
      if (moduleRef.wasmWaitingKey) {
        out.style.boxShadow = '0 0 0 2px #0dbc79';
      } else {
        out.style.boxShadow = '';
      }
      requestAnimationFrame(pollWaitingKey);
    }
    requestAnimationFrame(pollWaitingKey);

    var p = loadCreateBasicModular(baseUrl, opts.modularScript);
    if (showVfsTools) {
      p = p.then(function (x) {
        return loadVfsHelpers(baseUrl).then(
          function () {
            return x;
          },
          function () {
            return x;
          }
        );
      });
    }
    return p.then(function (createBasicModular) {
      return createBasicModular({
        locateFile: function (path) {
          if (path.endsWith('.wasm')) {
            return baseUrl + wasmName;
          }
          return baseUrl + path;
        },
        print: function (text) {
          writeStreamChunk(text, false);
        },
        printErr: function (text) {
          writeStreamChunk(text, true);
        },
        onWasmNeedInputLine: function () {
          inputLabelText.textContent =
            typeof moduleRef.wasmInputLabel === 'string' && moduleRef.wasmInputLabel.length
              ? moduleRef.wasmInputLabel
              : 'INPUT';
          inputRow.style.display = 'flex';
          inputLine.value = '';
          inputLine.focus();
        },
        onRuntimeInitialized: function () {
          moduleRef = this;
          runBtn.disabled = false;

          if (showVfsTools && global.RgcVfsHelpers && vfsHost) {
            try {
              var ui = global.RgcVfsHelpers.vfsMountUI(vfsHost, moduleRef, {
                pathDefault: opts.vfsExportPath || '/out.txt',
                onStatus: function (msg, isErr) {
                  appendOutputHtml(
                    '<span style="color:' + (isErr ? '#f14c4c' : '#888') + '">' + escHtml(msg) + '</span><br>',
                    false
                  );
                }
              });
              vfsRemove = ui.remove;
            } catch (e) {
              appendOutputHtml(
                '<span style="color:#f14c4c">' + escHtml(String(e && e.message ? e.message : e)) + '</span><br>',
                true
              );
            }
          }

          function doRunFromEditor() {
            clearOutput();
            inputRow.style.display = 'none';
            inputLine.value = '';
            moduleRef.wasmInputLabel = 'INPUT';
            moduleRef.wasmStopRequested = 0;
            moduleRef.wasmPaused = 0;
            var prog = showEditor ? ta.value : programDefault;
            var rc = moduleRef.ccall('basic_apply_arg_string', 'number', ['string'], [flags]);
            if (rc !== 0) {
              appendOutputHtml('<span style="color:#f14c4c">Invalid interpreter options.</span>', true);
              return;
            }
            moduleRef.FS.writeFile('/program.bas', prog);
            out.focus();
            runBtn.disabled = true;
            pauseBtn.disabled = !showPauseStop;
            resumeBtn.disabled = true;
            stopBtn.disabled = !showPauseStop;
            moduleRef
              .ccall('basic_load_and_run', null, ['string'], ['/program.bas'], { async: true })
              .catch(function (e) {
                appendOutputHtml(
                  '<span style="color:#f14c4c">' + escHtml(e && e.message ? e.message : e) + '</span>',
                  true
                );
              })
              .finally(function () {
                moduleRef.wasmPaused = 0;
                flushStreamTail(false);
                flushStreamTail(true);
                runBtn.disabled = false;
                pauseBtn.disabled = true;
                resumeBtn.disabled = true;
                stopBtn.disabled = true;
                if (scrollToError && out.dataset.error === '1') {
                  try {
                    out.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
                  } catch (e) {
                    out.scrollIntoView(true);
                  }
                }
              });
          }

          runBtn.onclick = function () {
            doRunFromEditor();
          };

          if (showEditor) {
            ta.addEventListener('keydown', function (ev) {
              if ((ev.ctrlKey || ev.metaKey) && ev.key === 'Enter') {
                ev.preventDefault();
                doRunFromEditor();
              }
            });
          }

          if (runOnEdit && showEditor) {
            ta.addEventListener('input', function () {
              if (runOnEditTimer) {
                clearTimeout(runOnEditTimer);
              }
              runOnEditTimer = setTimeout(function () {
                runOnEditTimer = null;
                if (!destroyed && moduleRef) {
                  doRunFromEditor();
                }
              }, runOnEditMs);
            });
          }

          pauseBtn.onclick = function () {
            moduleRef.wasmPaused = 1;
            pauseBtn.disabled = true;
            resumeBtn.disabled = false;
          };
          resumeBtn.onclick = function () {
            moduleRef.wasmPaused = 0;
            pauseBtn.disabled = false;
            resumeBtn.disabled = true;
          };
          stopBtn.onclick = function () {
            moduleRef.wasmStopRequested = 1;
            moduleRef.wasmPaused = 0;
          };

          out.addEventListener(
            'keydown',
            function (ev) {
              if (inputRow.style.display === 'flex') return;
              if (ev.target === ta) return;
              if (document.activeElement !== out && !out.contains(document.activeElement)) return;
              ev.preventDefault();
              var code = ev.keyCode || ev.which;
              if (code === 13) {
                moduleRef.ccall('wasm_push_key', null, ['number'], [13]);
              } else if (ev.key && ev.key.length === 1) {
                moduleRef.ccall('wasm_push_key', null, ['number'], [ev.key.charCodeAt(0) & 0xff]);
              }
            },
            true
          );

          inputLine.addEventListener('keydown', function (ev) {
            if (ev.key === 'Enter') {
              ev.preventDefault();
              moduleRef.wasmInputLineText = inputLine.value;
              moduleRef.wasmInputLineReady = 1;
              inputRow.style.display = 'none';
              out.focus();
            }
          });
        }
      }).then(function (Module) {
        moduleRef = Module;
        return {
          run: function () {
            if (runBtn.onclick) runBtn.onclick();
          },
          resetOutput: clearOutput,
          setProgram: function (src) {
            if (showEditor) ta.value = src;
          },
          getProgram: function () {
            return showEditor ? ta.value : programDefault;
          },
          destroy: function () {
            destroyed = true;
            if (runOnEditTimer) {
              clearTimeout(runOnEditTimer);
              runOnEditTimer = null;
            }
            if (vfsRemove) {
              try {
                vfsRemove();
              } catch (e) {}
              vfsRemove = null;
            }
            if (moduleRef) {
              try {
                moduleRef.wasmStopRequested = 1;
              } catch (e) {}
            }
            container.innerHTML = '';
            container.classList.remove('rgc-tutorial-embed');
          },
          getModule: function () {
            return moduleRef;
          }
        };
      });
    });
  }

  var embedApi = {
    mount: mount,
    resolveBaseUrl: resolveBaseUrl
  };
  global.RgcBasicTutorialEmbed = embedApi;
  /** @deprecated Use RgcBasicTutorialEmbed (RGC-BASIC rename). */
  global.CbmBasicTutorialEmbed = embedApi;
})(typeof window !== 'undefined' ? window : this);
