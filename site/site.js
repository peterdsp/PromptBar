/* PromptBar, promptbar.peterdsp.dev
   The live thing: type an address and it becomes a pill in the bar, which is
   all the app asks of you. Every section reads correctly without this file. */
(function () {
  'use strict';
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- the line you type ---------- */
  (function () {
    var url = document.getElementById('url');
    if (!url) return;
    var tab = document.getElementById('newTab');
    var nameEl = document.getElementById('newName');
    var initial = document.getElementById('newI');
    var title = document.getElementById('newTitle');
    var full = document.getElementById('newUrl');
    var tints = document.querySelectorAll('#tints button');
    var tries = document.querySelectorAll('.tries button');

    function parse(v) {
      v = v.trim();
      if (!v) return null;
      try {
        var u = new URL(/^https?:\/\//i.test(v) ? v : (/^localhost|^127\./i.test(v) ? 'http://' : 'https://') + v);
        var host = u.hostname.replace(/^www\./, '');
        var bits = host.split('.');
        var core = host === 'localhost' || /^\d+\./.test(host) ? 'Local' + (u.port ? ' ' + u.port : '') :
          bits.length > 2 ? bits[bits.length - 3] === 'chat' || bits[bits.length - 3] === 'assistant' ? bits[bits.length - 2] : bits[bits.length - 3] : bits[0];
        return { name: core.charAt(0).toUpperCase() + core.slice(1), href: u.origin };
      } catch (e) { return { name: v.slice(0, 24), href: v }; }
    }
    function render() {
      var p = parse(url.value);
      var n = p ? p.name : 'New chat';
      nameEl.textContent = n;
      initial.textContent = n.charAt(0).toUpperCase();
      title.textContent = n;
      full.textContent = p ? p.href : 'Paste an address to add one';
      [].forEach.call(tries, function (b) { b.setAttribute('aria-pressed', String(b.dataset.v === url.value.trim())); });
    }
    url.addEventListener('input', render);
    [].forEach.call(tries, function (b) {
      b.addEventListener('click', function () { url.value = b.dataset.v; render(); });
    });
    [].forEach.call(tints, function (b) {
      b.addEventListener('click', function () {
        tab.style.setProperty('--t', b.style.getPropertyValue('--t'));
        [].forEach.call(tints, function (o) { o.setAttribute('aria-pressed', String(o === b)); });
      });
    });
    render();
  })();

  if (reduce) return;

  /* ---------- the shutter on the chat inside the headline ---------- */
  var strip = document.querySelector('.shutter');
  if (strip) {
    strip.classList.add('pre');
    requestAnimationFrame(function () { requestAnimationFrame(function () {
      strip.classList.add('go');
      setTimeout(function () { strip.classList.add('settled'); }, 1600);
    }); });
    /* afterwards the picture drifts with the scroll, a slow look down the chat */
    var img = strip.querySelector('img');
    var ticking = false;
    addEventListener('scroll', function () {
      if (ticking) return; ticking = true;
      requestAnimationFrame(function () {
        var y = Math.min(scrollY, 900);
        img.style.setProperty('--drift', (-y * 0.06).toFixed(1) + 'px');
        ticking = false;
      });
    }, { passive: true });
  }

  /* ---------- entrances: heading, then text, then picture ---------- */
  var els = [].slice.call(document.querySelectorAll('main .rv:not(.hero .rv), .foot .rv'));
  if (!('IntersectionObserver' in window)) return;
  els.forEach(function (el) {
    var group = el.closest('article, .qa, .answer, section, footer');
    var sib = group ? [].slice.call(group.querySelectorAll('.rv')).indexOf(el) : 0;
    el.style.setProperty('--d', Math.min(sib, 5) * 80 + 'ms');
    el.classList.add('pre');
  });
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); e.target.classList.remove('pre'); io.unobserve(e.target); }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });
  els.forEach(function (el) { io.observe(el); });

  /* the hero's sentence and action arrive on load */
  [].forEach.call(document.querySelectorAll('.hero .rv'), function (el, i) {
    el.classList.add('pre'); el.style.setProperty('--d', 350 + i * 90 + 'ms');
    requestAnimationFrame(function () { requestAnimationFrame(function () { el.classList.add('in'); el.classList.remove('pre'); }); });
  });
})();
