/* PromptBar utility pages: entrances only. Content renders without this file. */
(function () {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) return;
  var t = document.querySelectorAll('main h1, main h2, main p, .facts, .kit figure, main .act, .foot h2, .foot .btn');
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); e.target.classList.remove('pre'); io.unobserve(e.target); } });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });
  for (var i = 0; i < t.length; i++) { t[i].classList.add('rv', 'pre'); t[i].style.setProperty('--d', (i % 4) * 70 + 'ms'); io.observe(t[i]); }
})();
