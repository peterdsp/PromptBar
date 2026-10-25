/* PromptBar, promptbar.peterdsp.dev
   The page's one live thing: the bar you fill. Paste a URL, give it a colour,
   and it appears in the popover, which is exactly what the app asks of you.
   Every section reads correctly with this file absent. */
(function () {
  'use strict';
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------------- the bar you fill ---------------- */
  (function () {
    var url = document.getElementById('url');
    var pick = document.getElementById('pick');
    var list = document.getElementById('outList');
    var count = document.getElementById('outCount');
    if (!url || !list) return;
    var colour = '#4db3ff';

    function nameFor(v) {
      v = v.trim();
      if (!v) return '';
      try {
        var h = new URL(/^https?:\/\//i.test(v) ? v : 'https://' + v).hostname.replace(/^www\./, '');
        var bits = h.split('.');
        var core = bits.length > 2 ? bits[bits.length - 2] : bits[0];
        return core.charAt(0).toUpperCase() + core.slice(1);
      } catch (e) { return v.slice(0, 28); }
    }

    function render() {
      var n = nameFor(url.value);
      list.innerHTML = '';
      if (!n) {
        var e = document.createElement('div');
        e.className = 'pop-empty';
        e.textContent = 'Nothing here yet. Paste a URL to add one.';
        list.appendChild(e);
        count.textContent = '0 in your bar';
        return;
      }
      var row = document.createElement('button');
      row.type = 'button';
      row.className = 'pop-row';
      row.setAttribute('aria-current', 'true');
      row.innerHTML = '<span class="sw"></span><span class="nm"></span><span class="kind">WKWebView</span>';
      row.querySelector('.sw').style.background = colour;
      row.querySelector('.sw').textContent = n.charAt(0).toUpperCase();
      row.querySelector('.nm').textContent = n;
      list.appendChild(row);
      count.textContent = '1 in your bar';
    }

    url.addEventListener('input', render);
    if (pick) {
      [].forEach.call(pick.querySelectorAll('button'), function (b) {
        b.addEventListener('click', function () {
          colour = b.dataset.c;
          [].forEach.call(pick.querySelectorAll('button'), function (o) {
            o.setAttribute('aria-pressed', String(o === b));
          });
          render();
        });
      });
    }
    render();
  })();

  /* ---------------- the switches ---------------- */
  [].forEach.call(document.querySelectorAll('.band-row .sw-btn'), function (b) {
    var row = b.closest('.band-row');
    function set(on) {
      b.setAttribute('aria-checked', String(on));
      row.setAttribute('data-on', String(on));
    }
    b.addEventListener('click', function () { set(b.getAttribute('aria-checked') !== 'true'); });
    b.addEventListener('keydown', function (e) {
      if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); b.click(); }
    });
  });

  /* ---------------- pointing it at an endpoint ---------------- */
  (function () {
    var scrub = document.getElementById('stScrub');
    if (!scrub) return;
    var clause = document.getElementById('stClause');
    var note = document.getElementById('stNote');
    var code = document.getElementById('stCode');
    var names = document.getElementById('stNames');

    var STEPS = [
      { n: 'Endpoint', c: 'Name the endpoint.',
        t: 'Anything that speaks the OpenAI chat API: a hosted service, a company gateway, or a runtime on your own machine.',
        j: { name: 'My endpoint', baseURL: 'https://api.example.com/v1' } },
      { n: 'Model', c: 'Choose the model.',
        t: 'Whatever that endpoint serves. PromptBar does not keep a list of its own, because it does not bundle providers.',
        j: { name: 'My endpoint', baseURL: 'https://api.example.com/v1', model: 'your-model' } },
      { n: 'Key', c: 'Paste the key once.',
        t: 'It goes straight to the macOS Keychain. Not UserDefaults, not iCloud, not a log file.',
        j: { name: 'My endpoint', baseURL: 'https://api.example.com/v1', model: 'your-model', apiKey: '* stored in macOS Keychain *' } },
      { n: 'Chat', c: 'Press the keys and talk.',
        t: 'Native streaming with server-sent events, cancellable mid-stream, straight from this Mac to that endpoint with nothing in between.',
        j: { name: 'My endpoint', baseURL: 'https://api.example.com/v1', model: 'your-model', apiKey: '* stored in macOS Keychain *', stream: true, systemPrompt: 'You are...' } }
    ];

    function paint(i) {
      var s = STEPS[i];
      clause.textContent = s.c;
      note.textContent = s.t;
      var lines = ['{'];
      var keys = Object.keys(s.j);
      keys.forEach(function (k, n) {
        var v = s.j[k];
        var out = typeof v === 'boolean' ? String(v) : '"' + v + '"';
        lines.push('  "' + k + '": ' + out + (n < keys.length - 1 ? ',' : ''));
      });
      lines.push('}');
      code.textContent = lines.join('\n');
      [].forEach.call(names.children, function (el, n) {
        if (n === i) el.setAttribute('aria-current', 'step'); else el.removeAttribute('aria-current');
      });
    }

    STEPS.forEach(function (s) {
      var el = document.createElement('span');
      el.textContent = s.n;
      names.appendChild(el);
    });
    scrub.addEventListener('input', function () { paint(+scrub.value); });
    paint(0);
  })();

  /* ---------------- the claims light one at a time ---------------- */
  (function () {
    var runs = [].slice.call(document.querySelectorAll('.claims .run span'));
    if (!runs.length) return;
    if (reduce) { runs[0].classList.add('lit'); return; }
    var k = 0;
    setInterval(function () {
      runs.forEach(function (s, i) { s.classList.toggle('lit', i === k); });
      k = (k + 1) % runs.length;
    }, 1400);
  })();

  /* ---------------- entrances ---------------- */
  (function () {
    var targets = document.querySelectorAll('section, .ticket, .band-row, .pop, .stage-fragment, .shot-grid figure, .io-field, h2, .claims .run, .ticket ul, .foot-mark');
    [].forEach.call(targets, function (el) {
      if (el.tagName !== 'SECTION' && !el.classList.contains('shutter')) el.classList.add('rise');
    });
    if (!('IntersectionObserver' in window) || reduce) {
      for (var i = 0; i < targets.length; i++) targets[i].classList.add('in');
      return;
    }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.06 });
    for (var k = 0; k < targets.length; k++) io.observe(targets[k]);
    requestAnimationFrame(function () {
      var h = document.querySelector('.hero');
      if (h) h.classList.add('in');
      var f = document.querySelector('.stage-fragment');
      if (f) f.classList.add('in');
    });
  })();
})();
