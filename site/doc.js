/* PromptBar utility pages: entrances only. Content renders without this file. */
(function () {
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var t = document.querySelectorAll('h1, h2, p, .facts, .kit figure, .act, .foot-mark, .foot-meta');
  for (var i = 0; i < t.length; i++) t[i].classList.add('rise');
  if (!('IntersectionObserver' in window) || reduce) {
    for (var k = 0; k < t.length; k++) t[k].classList.add('in');
    return;
  }
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });
  for (var j = 0; j < t.length; j++) io.observe(t[j]);
})();
