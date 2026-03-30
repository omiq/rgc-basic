/**
 * Mount all RGC-BASIC embeds on the page (front + block editor preview).
 * Config is in <script type="application/json" class="rgc-basic-embed-config"> per block.
 */
(function () {
  'use strict';

  function parseConfigs() {
    var nodes = document.querySelectorAll('.rgc-basic-embed-config');
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
      try {
        var cfg = JSON.parse(nodes[i].textContent || '{}');
        out.push({ scriptNode: nodes[i], config: cfg });
      } catch (e) {
        console.warn('RGC-BASIC block: invalid JSON config', e);
      }
    }
    return out;
  }

  function mountAll() {
    if (typeof window.RgcBasicTutorialEmbed === 'undefined' || !window.RgcBasicTutorialEmbed.mount) {
      return false;
    }
    var base = (window.rgcBasicTutorialBlock && window.rgcBasicTutorialBlock.baseUrl) || '';
    var list = parseConfigs();
    for (var j = 0; j < list.length; j++) {
      var item = list[j];
      var sn = item.scriptNode;
      var parent = sn.parentNode;
      if (!parent || parent.getAttribute('data-rgc-mounted')) {
        continue;
      }
      parent.setAttribute('data-rgc-mounted', '1');
      var mountPoint = document.createElement('div');
      mountPoint.className = 'rgc-basic-tutorial-mount';
      parent.insertBefore(mountPoint, sn);
      var opts = item.config || {};
      if (base && !opts.baseUrl) {
        opts.baseUrl = base;
      }
      window.RgcBasicTutorialEmbed.mount(mountPoint, opts).catch(function (err) {
        console.error('RGC-BASIC mount failed', err);
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
