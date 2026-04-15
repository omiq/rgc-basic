/**
 * RGC-BASIC syntax highlighter — shared by the tutorial-embed and gfx-embed
 * textareas. Exposes window.RgcBasicHighlight = { attach, highlight }.
 *
 * Uses a twin-overlay technique: a <pre><code> sits behind a transparent
 * <textarea>; on every input event we re-render highlighted HTML and sync
 * scroll position. No dependencies.
 */
(function (global) {
  'use strict';

  if (global.RgcBasicHighlight) return; // idempotent across multiple enqueues

  var KEYWORDS = [
    'IF','THEN','ELSE','ELSEIF','ENDIF','END','FOR','TO','STEP','NEXT',
    'GOTO','GOSUB','RETURN','PRINT','INPUT','LET','DIM','REM','WHILE',
    'WEND','DO','LOOP','UNTIL','REPEAT','DATA','READ','RESTORE','DEF',
    'FN','ON','OFF','AS','OPEN','CLOSE','GET','PUT','CLS','CLR','POKE',
    'PEEK','WAIT','SYS','STOP','CONT','RUN','NEW','LIST','RANDOMIZE',
    'CONTINUE','EXIT','BREAK','SELECT','CASE','SUB','ENDSUB','CALL',
    'FUNCTION','ENDFUNCTION','GLOBAL','LOCAL','STATIC','OPTION','SWAP'
  ];
  var FUNCS = [
    'ABS','ASC','ATN','CHR\\$','COS','EXP','INT','LEN','LOG','MID\\$',
    'LEFT\\$','RIGHT\\$','RND','SGN','SIN','SPC','STR\\$','SQR','TAB',
    'TAN','VAL','HTTP\\$','HTTPSTATUS','EXEC\\$','TIME','TIME\\$',
    'DATE\\$','INKEY\\$','GETKEY\\$','POS','USR','FRE','HEX\\$','OCT\\$',
    'BIN\\$','INSTR','UCASE\\$','LCASE\\$','TRIM\\$','LTRIM\\$','RTRIM\\$',
    'SPACE\\$','STRING\\$','ATN2','CEIL','FLOOR','ROUND','POW','MOD',
    'MIN','MAX','PI'
  ];
  var OPS = ['AND','OR','NOT','XOR','MOD'];

  var KW_SET  = new RegExp('^(' + KEYWORDS.join('|') + ')$', 'i');
  var OP_SET  = new RegExp('^(' + OPS.join('|')      + ')$', 'i');
  var FN_SET  = new RegExp('^(' + FUNCS.join('|').replace(/\\\$/g, '\\$') + ')$', 'i');
  var NUM_RE    = /\b(\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?\b/g;
  var LINENO_RE = /^(\s*)(\d+)(?=\s)/;

  function escapeHtml(s) {
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function highlightLine(line) {
    if (line.length === 0) return '\u200B'; // keep line height

    var out = '';
    var i = 0;
    var len = line.length;

    var m = LINENO_RE.exec(line);
    if (m) {
      out += m[1] + '<span class="tok-lineno">' + m[2] + '</span>';
      i = m[0].length;
    }

    while (i < len) {
      var c = line.charAt(i);

      // Comment: tick or REM to end of line
      if (c === "'") {
        out += '<span class="tok-comment">' + escapeHtml(line.slice(i)) + '</span>';
        break;
      }
      if ((c === 'R' || c === 'r') && /^rem\b/i.test(line.slice(i))) {
        out += '<span class="tok-comment">' + escapeHtml(line.slice(i)) + '</span>';
        break;
      }

      // Directive: #OPTION ... at start of line
      if (c === '#' && i === 0) {
        out += '<span class="tok-directive">' + escapeHtml(line.slice(i)) + '</span>';
        i = len;
        continue;
      }

      // String literal "..."
      if (c === '"') {
        var j = i + 1;
        while (j < len && line.charAt(j) !== '"') j++;
        if (j < len) j++;
        var str = line.slice(i, j);
        var strHtml = escapeHtml(str).replace(/\{[^{}]+\}/g, function (esc) {
          return '<span class="tok-escape">' + esc + '</span>';
        });
        out += '<span class="tok-string">' + strHtml + '</span>';
        i = j;
        continue;
      }

      // Number
      NUM_RE.lastIndex = i;
      var nm = NUM_RE.exec(line);
      if (nm && nm.index === i) {
        out += '<span class="tok-number">' + escapeHtml(nm[0]) + '</span>';
        i += nm[0].length;
        continue;
      }

      // Identifier / keyword / function / operator
      if (/[A-Za-z_]/.test(c)) {
        var k = i + 1;
        while (k < len && /[A-Za-z0-9_]/.test(line.charAt(k))) k++;
        if (k < len && line.charAt(k) === '$') k++;
        var word = line.slice(i, k);
        var cls;
        if (KW_SET.test(word)) {
          cls = 'tok-keyword';
        } else if (OP_SET.test(word)) {
          cls = 'tok-operator';
        } else if (FN_SET.test(word) && line.charAt(k) === '(') {
          cls = 'tok-function';
        } else {
          cls = 'tok-ident';
        }
        out += '<span class="' + cls + '">' + escapeHtml(word) + '</span>';
        i = k;
        continue;
      }

      // Punctuation / operators
      if (/[=+\-*/^<>(),:;?]/.test(c)) {
        var oEnd = i + 1;
        if ((c === '<' || c === '>') && (line.charAt(oEnd) === '=' || line.charAt(oEnd) === '>')) {
          oEnd++;
        }
        out += '<span class="tok-punct">' + escapeHtml(line.slice(i, oEnd)) + '</span>';
        i = oEnd;
        continue;
      }

      out += escapeHtml(c);
      i++;
    }
    return out;
  }

  function highlight(src) {
    var lines = String(src == null ? '' : src).split('\n');
    var html = '';
    for (var i = 0; i < lines.length; i++) {
      html += highlightLine(lines[i]) + '\n';
    }
    return html;
  }

  /**
   * Wrap a <textarea> with a syntax-highlighting overlay. Returns the new
   * wrapper element. Safe to call multiple times on the same textarea — only
   * the first call attaches; subsequent calls are no-ops returning the
   * existing wrapper.
   */
  function attach(ta) {
    if (!ta || ta.dataset.rgcHighlighted === '1') {
      return ta && ta.parentNode && ta.parentNode.classList &&
             ta.parentNode.classList.contains('rgc-basic-editor')
        ? ta.parentNode : null;
    }
    ta.dataset.rgcHighlighted = '1';

    var wrap = document.createElement('div');
    wrap.className = 'rgc-basic-editor';

    var pre = document.createElement('pre');
    pre.className = 'rgc-basic-editor-highlight';
    pre.setAttribute('aria-hidden', 'true');
    var code = document.createElement('code');
    pre.appendChild(code);

    var parent = ta.parentNode;
    if (parent) parent.insertBefore(wrap, ta);
    wrap.appendChild(pre);
    wrap.appendChild(ta);
    ta.classList.add('rgc-basic-editor-input');

    function render() { code.innerHTML = highlight(ta.value); }
    function syncScroll() {
      pre.scrollTop = ta.scrollTop;
      pre.scrollLeft = ta.scrollLeft;
    }

    ta.addEventListener('input', function () { render(); syncScroll(); });
    ta.addEventListener('scroll', syncScroll);
    ta.addEventListener('keyup', syncScroll);
    ta.addEventListener('keydown', function (e) {
      if (e.key === 'Tab' && !e.shiftKey) {
        e.preventDefault();
        var s = ta.selectionStart, eEnd = ta.selectionEnd;
        ta.value = ta.value.slice(0, s) + '  ' + ta.value.slice(eEnd);
        ta.selectionStart = ta.selectionEnd = s + 2;
        render();
        syncScroll();
      }
    });

    render();
    return wrap;
  }

  global.RgcBasicHighlight = { attach: attach, highlight: highlight };
})(typeof window !== 'undefined' ? window : this);
