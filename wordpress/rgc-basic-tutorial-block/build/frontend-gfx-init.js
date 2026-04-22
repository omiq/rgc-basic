/**
 * Mount RGC-BASIC GFX embeds (raylib/WebGL2 iframe). Config in
 * <script type="application/json" class="rgc-basic-gfx-embed-config"> per block.
 */
(function () {
  'use strict';

  function parseConfigs() {
    var nodes = document.querySelectorAll('.rgc-basic-gfx-embed-config');
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
      try {
        var cfg = JSON.parse(nodes[i].textContent || '{}');
        out.push({ scriptNode: nodes[i], config: cfg });
      } catch (e) {
        console.warn('RGC-BASIC GFX block: invalid JSON config', e);
      }
    }
    return out;
  }

  function mountAll() {
    if (typeof window.RgcBasicGfxEmbed === 'undefined' || !window.RgcBasicGfxEmbed.mount) {
      return false;
    }
    var base = (window.rgcBasicGfxBlock && window.rgcBasicGfxBlock.wasmBaseUrl) || '';
    var list = parseConfigs();
    for (var j = 0; j < list.length; j++) {
      var item = list[j];
      var sn = item.scriptNode;
      var parent = sn.parentNode;
      if (!parent || parent.getAttribute('data-rgc-gfx-mounted')) {
        continue;
      }
      parent.setAttribute('data-rgc-gfx-mounted', '1');
      var mountPoint = document.createElement('div');
      mountPoint.className = 'rgc-basic-gfx-mount';
      parent.insertBefore(mountPoint, sn);
      var opts = item.config || {};
      if (base && !opts.wasmBaseUrl) {
        opts.wasmBaseUrl = base;
      }
      window.RgcBasicGfxEmbed.mount(mountPoint, opts).catch(function (err) {
        console.error('RGC-BASIC GFX mount failed', err);
      });
    }
    return true;
  }

  function tryMountLoop() {
    if (mountAll()) {
      return;
    }
    setTimeout(tryMountLoop, 50);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', tryMountLoop);
  } else {
    tryMountLoop();
  }
})();
