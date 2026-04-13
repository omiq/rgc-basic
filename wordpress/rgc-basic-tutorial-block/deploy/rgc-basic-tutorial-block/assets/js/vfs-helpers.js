/**
 * Upload files into / download files from Emscripten MEMFS (Module.FS).
 * Used by index.html, canvas.html, tutorial-embed.js.
 */
(function (global) {
  'use strict';

  function normalizeVfsPath(path) {
    var p = String(path || '').trim();
    if (!p) return null;
    if (p.indexOf('..') !== -1) return null;
    p = p.replace(/\\/g, '/');
    if (p.charAt(0) !== '/') p = '/' + p;
    return p;
  }

  /**
   * @param {object} Module - Emscripten module with FS
   * @param {FileList|File[]} files
   * @param {function(string, boolean)} [onStatus] - (message, isError)
   * @returns {Promise<string[]>} uploaded absolute paths
   */
  function vfsUploadFiles(Module, files, onStatus) {
    if (!Module || !Module.FS) {
      var e = new Error('Virtual FS not ready (wait for WASM to load).');
      if (onStatus) onStatus(e.message, true);
      return Promise.reject(e);
    }
    var list = files && files.length ? Array.prototype.slice.call(files) : [];
    if (!list.length) return Promise.resolve([]);

    return Promise.all(
      list.map(function (file) {
        return new Promise(function (resolve, reject) {
          var reader = new FileReader();
          reader.onload = function () {
            try {
              var u8 = new Uint8Array(reader.result);
              var name = file.name || 'upload.bin';
              var path = normalizeVfsPath(name);
              if (!path) {
                reject(new Error('Invalid filename (no ".." allowed): ' + name));
                return;
              }
              var segs = path.split('/').filter(Boolean);
              var acc = '';
              for (var i = 0; i < segs.length - 1; i++) {
                acc += '/' + segs[i];
                try {
                  Module.FS.mkdir(acc);
                } catch (mkdirErr) {
                  /* exists */
                }
              }
              Module.FS.writeFile(path, u8);
              if (onStatus) onStatus('Uploaded: ' + path, false);
              resolve(path);
            } catch (err) {
              reject(err);
            }
          };
          reader.onerror = function () {
            reject(new Error('Could not read file: ' + (file.name || '?')));
          };
          reader.readAsArrayBuffer(file);
        });
      })
    );
  }

  /**
   * @param {object} Module
   * @param {string} path - e.g. /out.txt or out.txt
   * @param {string} [suggestedName] - download filename
   */
  function vfsExportFile(Module, path, suggestedName) {
    if (!Module || !Module.FS) {
      throw new Error('Virtual FS not ready.');
    }
    var p = normalizeVfsPath(path);
    if (!p) {
      throw new Error('Invalid path.');
    }
    var st;
    try {
      st = Module.FS.stat(p);
    } catch (e) {
      throw new Error('File not found in VFS: ' + p);
    }
    if (Module.FS.isDir(st.mode)) {
      throw new Error('Cannot download a directory: ' + p);
    }
    var data = Module.FS.readFile(p);
    var blob = new Blob([data], { type: 'application/octet-stream' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = suggestedName || p.split('/').pop() || 'download.bin';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () {
      URL.revokeObjectURL(a.href);
    }, 2500);
  }

  /**
   * @param {HTMLElement} container - where to append controls
   * @param {object} Module - Emscripten module (must have FS)
   * @param {object} [options]
   * @param {function(string, boolean)} [options.onStatus]
   * @param {string} [options.uploadLabel]
   * @param {string} [options.exportLabel]
   * @param {string} [options.pathPlaceholder]
   * @param {string} [options.pathDefault]
   * @returns {{ remove: function, pathInput: HTMLInputElement }}
   */
  function vfsMountUI(container, Module, options) {
    options = options || {};
    var onStatus =
      options.onStatus ||
      function () {
        /* no-op */
      };

    var wrap = document.createElement('div');
    wrap.className = 'rgc-vfs-tools';
    wrap.style.marginTop = '0.35rem';

    var fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.multiple = true;
    fileInput.style.display = 'none';

    var btnUpload = document.createElement('button');
    btnUpload.type = 'button';
    btnUpload.textContent = options.uploadLabel || 'Upload to VFS';

    var pathInput = document.createElement('input');
    pathInput.type = 'text';
    pathInput.placeholder = options.pathPlaceholder || '/out.txt';
    pathInput.title = 'Path in WASM virtual FS (OPEN/PRINT#/etc.)';
    pathInput.size = options.pathWidth || 26;
    if (options.pathDefault) {
      pathInput.value = options.pathDefault;
    }

    var btnExport = document.createElement('button');
    btnExport.type = 'button';
    btnExport.textContent = options.exportLabel || 'Download from VFS';

    btnUpload.addEventListener('click', function () {
      fileInput.click();
    });

    fileInput.addEventListener('change', function () {
      if (!fileInput.files || !fileInput.files.length) return;
      vfsUploadFiles(Module, fileInput.files, onStatus).then(
        function () {
          fileInput.value = '';
        },
        function (err) {
          onStatus(String(err && err.message ? err.message : err), true);
          fileInput.value = '';
        }
      );
    });

    btnExport.addEventListener('click', function () {
      try {
        var raw = pathInput.value.trim() || '/out.txt';
        vfsExportFile(Module, raw);
        onStatus('Download started: ' + normalizeVfsPath(raw), false);
      } catch (err) {
        onStatus(String(err && err.message ? err.message : err), true);
      }
    });

    wrap.appendChild(btnUpload);
    wrap.appendChild(fileInput);
    wrap.appendChild(document.createTextNode(' '));
    wrap.appendChild(pathInput);
    wrap.appendChild(document.createTextNode(' '));
    wrap.appendChild(btnExport);
    container.appendChild(wrap);

    return {
      pathInput: pathInput,
      remove: function () {
        if (wrap.parentNode) {
          wrap.parentNode.removeChild(wrap);
        }
      }
    };
  }

  var vfsApi = {
    normalizeVfsPath: normalizeVfsPath,
    vfsUploadFiles: vfsUploadFiles,
    vfsExportFile: vfsExportFile,
    vfsMountUI: vfsMountUI
  };
  global.RgcVfsHelpers = vfsApi;
  /** @deprecated Use RgcVfsHelpers (RGC-BASIC rename). */
  global.CbmVfsHelpers = vfsApi;
})(typeof window !== 'undefined' ? window : this);
