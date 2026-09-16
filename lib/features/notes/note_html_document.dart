import '../../data/content/content_api.dart' show contentApiBaseUrl;

/// Wraps CMS / asset note HTML with KaTeX + base URL for uploaded media.
String wrapNoteHtmlDocument(String bodyHtml, {String? sectionAnchor}) {
  final base = contentApiBaseUrl().replaceAll(RegExp(r'/$'), '');
  final body = bodyHtml.trim().startsWith('<')
      ? bodyHtml
      : '<p>${_escape(bodyHtml)}</p>';

  final safeAnchor = _safeDomId(sectionAnchor);
  final anchorScript = safeAnchor.isNotEmpty
      ? '''
<script>
  window.addEventListener('load', function () {
    var el = document.getElementById('$safeAnchor');
    if (el) el.scrollIntoView({ block: 'start' });
  });
</script>
'''
      : '';

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <base href="$base/" />
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@600;700&family=DM+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>
    :root {
      --ink: #16131f;
      --ink-soft: #4a4558;
      --muted: #7a7489;
      --bg: #f6f4fb;
      --surface: #ffffff;
      --border: #e6e1f2;
      --purple: #6c63ff;
      --purple-dark: #4f46d9;
      --purple-soft: #eeecff;
      --teal: #0f8a72;
      --teal-soft: #e6f7f1;
      --amber: #c47a0a;
      --amber-soft: #fff6e8;
      --coral: #d8553a;
      --coral-soft: #fdeee8;
      --radius: 14px;
      --yellow: #ffe566;
      --pink: #ffb3d1;
      --mint: #b8f0d8;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 20px 18px 88px;
      font-family: "DM Sans", system-ui, -apple-system, sans-serif;
      font-size: 16.5px;
      line-height: 1.65;
      color: var(--ink-soft);
      background:
        radial-gradient(ellipse 80% 50% at 100% -10%, rgba(108,99,255,0.12), transparent 55%),
        radial-gradient(ellipse 60% 40% at -10% 20%, rgba(15,138,114,0.08), transparent 50%),
        var(--bg);
      -webkit-font-smoothing: antialiased;
      -webkit-user-select: text;
      user-select: text;
    }
    img, video {
      max-width: 100%;
      height: auto;
      border-radius: 12px;
      display: block;
      margin: 16px 0;
    }
    h1, h2, h3 {
      font-family: "Space Grotesk", system-ui, sans-serif;
      color: var(--ink);
      line-height: 1.25;
      letter-spacing: -0.02em;
    }
    h2 {
      font-size: 1.35rem;
      font-weight: 700;
      margin: 8px 0 14px;
    }
    h3 {
      font-size: 1.05rem;
      font-weight: 600;
      margin: 22px 0 10px;
      color: var(--ink);
    }
    p { margin: 0 0 14px; }
    p.lead {
      font-size: 1.02rem;
      color: var(--ink);
      font-weight: 500;
      margin-bottom: 18px;
    }
    strong { color: var(--ink); font-weight: 650; }
    .katex-display { overflow-x: auto; overflow-y: hidden; padding: 4px 0; }

    .hl, mark.hl,
    .hl-pink, mark.hl-pink,
    .hl-mint, mark.hl-mint {
      color: inherit;
      font: inherit;
      line-height: inherit;
      padding: 0.08em 0.14em;
      margin: 0 0.02em;
      border-radius: 0.2em;
      box-decoration-break: clone;
      -webkit-box-decoration-break: clone;
    }
    .hl, mark.hl {
      background-color: rgba(255, 214, 10, 0.45);
    }
    .hl-pink, mark.hl-pink {
      background-color: rgba(255, 140, 180, 0.4);
    }
    .hl-mint, mark.hl-mint {
      background-color: rgba(80, 210, 160, 0.35);
    }
    .u {
      text-decoration: none;
      border-bottom: 0.12em solid var(--purple);
      padding-bottom: 0.05em;
    }
    .u-wavy {
      text-decoration: underline wavy var(--coral);
      text-underline-offset: 0.18em;
      text-decoration-thickness: 0.08em;
    }
    .u-double {
      text-decoration: underline double var(--teal);
      text-underline-offset: 0.18em;
      text-decoration-thickness: 0.08em;
    }

    .note-hero {
      background: linear-gradient(135deg, #4f46d9 0%, #6c63ff 55%, #7b73ff 100%);
      color: #fff;
      border-radius: 18px;
      padding: 22px 20px 20px;
      margin: 0 0 22px;
      box-shadow: 0 10px 28px rgba(79, 70, 217, 0.22);
    }
    .note-hero .eyebrow {
      margin: 0 0 8px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      opacity: 0.85;
    }
    .note-hero h2 {
      color: #fff;
      margin: 0 0 10px;
      font-size: 1.45rem;
    }
    .note-hero p { margin: 0; color: rgba(255,255,255,0.9); font-size: 0.98rem; }

    .section-label {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 42px;
      height: 28px;
      padding: 0 10px;
      margin: 18px 0 8px;
      border-radius: 9px;
      background: var(--purple);
      color: #fff;
      font-family: "Space Grotesk", system-ui, sans-serif;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.02em;
    }
    .section-label + h2 { margin-top: 0; }

    .key-term {
      background: var(--purple-soft);
      border-left: 4px solid var(--purple);
      border-radius: 0 12px 12px 0;
      padding: 14px 16px;
      margin: 16px 0;
    }
    .key-term .kt-label {
      display: block;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--purple-dark);
      margin-bottom: 4px;
    }
    .key-term strong { color: var(--ink); }

    ul.note-list, ol.note-list {
      list-style: none;
      margin: 0 0 16px;
      padding: 0;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      overflow: hidden;
    }
    ul.note-list li, ol.note-list li {
      position: relative;
      padding: 11px 14px 11px 34px;
      border-bottom: 1px solid var(--border);
      color: var(--ink-soft);
      font-size: 15.5px;
    }
    ul.note-list li:last-child, ol.note-list li:last-child { border-bottom: none; }
    ul.note-list li::before {
      content: "";
      position: absolute;
      left: 14px;
      top: 18px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--purple);
    }
    ol.note-list { counter-reset: steps; }
    ol.note-list li { padding-left: 44px; }
    ol.note-list li::before {
      counter-increment: steps;
      content: counter(steps);
      position: absolute;
      left: 12px;
      top: 10px;
      width: 22px;
      height: 22px;
      border-radius: 7px;
      background: var(--purple-soft);
      color: var(--purple-dark);
      font-size: 12px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: "Space Grotesk", system-ui, sans-serif;
    }

    .callout {
      border-radius: var(--radius);
      padding: 14px 16px;
      margin: 16px 0;
    }
    .callout-label {
      display: block;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .callout p { margin: 0; font-size: 15px; }
    .callout.example {
      background: var(--amber-soft);
      border: 1px solid #f0d9a8;
    }
    .callout.example .callout-label { color: var(--amber); }
    .callout.tip {
      background: var(--teal-soft);
      border: 1px solid #b7e5d6;
    }
    .callout.tip .callout-label { color: var(--teal); }
    .callout.exam {
      background: var(--surface);
      border: 1.5px solid var(--purple);
    }
    .callout.exam .callout-label { color: var(--purple-dark); }
    .callout.exam .note-list {
      border: none;
      background: transparent;
      margin: 0;
    }
    .callout.exam .note-list li {
      border-bottom-color: var(--border);
      padding-left: 28px;
    }

    .summary-box {
      background: linear-gradient(145deg, #2a2550 0%, #3d3480 100%);
      border-radius: 18px;
      padding: 20px 18px;
      margin: 22px 0 8px;
      color: rgba(255,255,255,0.92);
    }
    .summary-box h3 {
      color: #fff;
      margin: 0 0 12px;
      font-size: 1.15rem;
    }
    .summary-box .note-list {
      background: transparent;
      border: none;
      margin: 0;
    }
    .summary-box .note-list li {
      color: rgba(255,255,255,0.92);
      border-bottom-color: rgba(255,255,255,0.12);
      padding-left: 28px;
    }
    .summary-box .note-list li::before {
      background: #a89eff;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin: 14px 0 18px;
      font-size: 14.5px;
      background: var(--surface);
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid var(--border);
    }
    th, td {
      padding: 10px 12px;
      text-align: left;
      border-bottom: 1px solid var(--border);
    }
    th {
      background: var(--purple-soft);
      color: var(--purple-dark);
      font-weight: 700;
      font-size: 13px;
    }
    tr:last-child td { border-bottom: none; }

    blockquote {
      margin: 16px 0;
      padding: 14px 16px;
      border-radius: var(--radius);
      background: var(--teal-soft);
      border-left: 4px solid var(--teal);
      color: var(--ink-soft);
    }
    blockquote p { margin: 0; }

    .margin-note {
      display: block;
      margin: 8px 0 14px;
      padding-left: 12px;
      border-left: 3px solid var(--coral);
      color: var(--coral);
      font-size: 14px;
      font-weight: 600;
    }

    #chkela-explain-bar {
      display: none;
      position: fixed;
      left: 50%;
      bottom: 20px;
      z-index: 9999;
      transform: translateX(-50%) translateY(12px) scale(0.96);
      opacity: 0;
      align-items: center;
      gap: 12px;
      max-width: calc(100vw - 28px);
      padding: 12px 14px 12px 12px;
      border: 0;
      border-radius: 999px;
      color: #fff;
      background: linear-gradient(135deg, #7B6CFF 0%, #5B4BFF 48%, #4F46D9 100%);
      box-shadow:
        0 12px 28px rgba(91, 75, 255, 0.42),
        0 0 0 1px rgba(255, 255, 255, 0.18) inset;
      font: 700 14px "DM Sans", system-ui, sans-serif;
      letter-spacing: -0.01em;
      text-align: left;
      cursor: pointer;
      -webkit-tap-highlight-color: transparent;
      animation: chkela-explain-pulse 1.8s ease-in-out infinite;
    }
    #chkela-explain-bar.chkela-explain-visible {
      display: inline-flex;
      opacity: 1;
      transform: translateX(-50%) translateY(0) scale(1);
      transition: opacity 160ms ease, transform 220ms cubic-bezier(0.2, 0.9, 0.2, 1);
    }
    #chkela-explain-bar .chkela-explain-icon {
      flex: 0 0 auto;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      display: grid;
      place-items: center;
      background: rgba(255, 255, 255, 0.18);
      box-shadow: 0 0 0 4px rgba(255, 255, 255, 0.08);
      font-size: 18px;
      line-height: 1;
    }
    #chkela-explain-bar .chkela-explain-copy {
      display: flex;
      flex-direction: column;
      gap: 1px;
      min-width: 0;
      padding-right: 4px;
    }
    #chkela-explain-bar .chkela-explain-title {
      font-size: 14px;
      font-weight: 750;
      line-height: 1.2;
      white-space: nowrap;
    }
    #chkela-explain-bar .chkela-explain-sub {
      font-size: 11px;
      font-weight: 560;
      opacity: 0.88;
      line-height: 1.2;
      white-space: nowrap;
    }
    #chkela-explain-bar .chkela-explain-chevron {
      flex: 0 0 auto;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      display: grid;
      place-items: center;
      background: rgba(255, 255, 255, 0.16);
      font-size: 16px;
      font-weight: 700;
    }
    @keyframes chkela-explain-pulse {
      0%, 100% { box-shadow: 0 12px 28px rgba(91, 75, 255, 0.42), 0 0 0 0 rgba(123, 108, 255, 0.45); }
      50% { box-shadow: 0 14px 32px rgba(91, 75, 255, 0.5), 0 0 0 10px rgba(123, 108, 255, 0); }
    }
  </style>
</head>
<body>
$body
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
<script>
  (function () {
    function renderMath() {
      if (!window.renderMathInElement) return;
      try {
        renderMathInElement(document.body, {
          delimiters: [
            {left: '\$\$', right: '\$\$', display: true},
            {left: '\$', right: '\$', display: false},
            {left: '\\\\(', right: '\\\\)', display: false},
            {left: '\\\\[', right: '\\\\]', display: true}
          ],
          throwOnError: false
        });
      } catch (e) {}
    }

    function initExplainBar() {
      if (document.getElementById('chkela-explain-bar')) return;

      var bar = document.createElement('button');
      bar.id = 'chkela-explain-bar';
      bar.type = 'button';
      bar.setAttribute('aria-label', 'Explain selected text with AI');
      bar.innerHTML =
        '<span class="chkela-explain-icon" aria-hidden="true">✨</span>' +
        '<span class="chkela-explain-copy">' +
          '<span class="chkela-explain-title">Explain with AI</span>' +
          '<span class="chkela-explain-sub">Tap for a clear breakdown</span>' +
        '</span>' +
        '<span class="chkela-explain-chevron" aria-hidden="true">→</span>';
      document.body.appendChild(bar);

      var lastText = '';
      var hideTimer = null;

      function selectedText() {
        var sel = window.getSelection && window.getSelection();
        return sel ? String(sel.toString() || '').trim() : '';
      }

      function placeBar() {
        var sel = window.getSelection && window.getSelection();
        var top = null;
        try {
          if (sel && sel.rangeCount > 0 && !sel.isCollapsed) {
            var rect = sel.getRangeAt(0).getBoundingClientRect();
            if (rect && (rect.width || rect.height)) {
              top = Math.min(
                Math.max(rect.bottom + 12, 72),
                window.innerHeight - 76
              );
            }
          }
        } catch (e) {}
        if (top == null) {
          bar.style.top = '';
          bar.style.bottom = '20px';
        } else {
          bar.style.bottom = 'auto';
          bar.style.top = top + 'px';
        }
      }

      function showBar() {
        placeBar();
        bar.classList.add('chkela-explain-visible');
      }

      function hideBar() {
        bar.classList.remove('chkela-explain-visible');
        bar.style.top = '';
        bar.style.bottom = '20px';
      }

      function syncBar() {
        var text = selectedText();
        if (text.length >= 8) {
          lastText = text;
          if (hideTimer) {
            clearTimeout(hideTimer);
            hideTimer = null;
          }
          showBar();
          return;
        }
        // Keep bar briefly so iOS can deliver the tap before selection clears.
        if (!hideTimer) {
          hideTimer = setTimeout(function () {
            hideTimer = null;
            if (selectedText().length < 8) hideBar();
          }, 320);
        }
      }

      function sendExplain(e) {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
        }
        var text = selectedText() || lastText;
        text = String(text || '').trim();
        if (text.length < 8) return;
        try {
          if (window.ChkelaExplain && window.ChkelaExplain.postMessage) {
            window.ChkelaExplain.postMessage(text);
          }
        } catch (err) {}
        lastText = '';
        hideBar();
        try {
          var sel = window.getSelection && window.getSelection();
          if (sel && sel.removeAllRanges) sel.removeAllRanges();
        } catch (err2) {}
      }

      document.addEventListener('selectionchange', syncBar);
      document.addEventListener('mouseup', syncBar);
      document.addEventListener('touchend', syncBar);
      window.addEventListener('scroll', placeBar, { passive: true });
      bar.addEventListener('touchstart', sendExplain, { passive: false });
      bar.addEventListener('mousedown', sendExplain);
      bar.addEventListener('click', sendExplain);
    }

    function boot() {
      renderMath();
      initExplainBar();
    }

    // loadHtmlString often finishes before DOMContentLoaded can fire again.
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', boot);
    } else {
      boot();
    }
    window.addEventListener('load', function () {
      renderMath();
      initExplainBar();
    });
  })();
</script>
$anchorScript
</body>
</html>
''';
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Only allow safe DOM id characters before injecting into note scroll script.
String _safeDomId(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.:-]*$').hasMatch(value)) return '';
  return value;
}