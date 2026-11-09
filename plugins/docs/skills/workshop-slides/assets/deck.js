(() => {
  const slides = [...document.querySelectorAll('.slide')];
  const counter = document.getElementById('counter');
  const progress = document.getElementById('progress');
  const last = slides.length - 1;
  const showAll = new URLSearchParams(location.search).has('all');
  if (showAll) document.documentElement.classList.add('show-all');
  let cur = -1;
  const frags = s => [...s.querySelectorAll('.frag')];

  // key: token of [data-hl] to emphasise; the same key again (or '') clears
  function setHl(s, key) {
    const on = key && s.dataset.hlOn !== key ? key : '';
    if (on) s.dataset.hlOn = on; else delete s.dataset.hlOn;
    s.querySelectorAll('[data-hl]').forEach(el => {
      const hit = el.dataset.hl.split(' ').includes(on);
      el.classList.toggle('lit', !!on && hit);
      el.classList.toggle('dim', !!on && !hit);
    });
    s.querySelectorAll('[data-hl-btn]').forEach(b => b.setAttribute('aria-pressed', String(!!on && b.dataset.hlBtn === on)));
  }

  // shortcut: one shared 1 s interval; a started timer pauses any other running one
  let tick = null, running = null;
  const fmt = sec => Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
  function pauseTimer() { clearInterval(tick); if (running) running.classList.remove('run'); running = null; }
  function toggleTimer(btn) {
    if (running === btn) return pauseTimer();
    pauseTimer();
    if (btn.classList.contains('done')) { btn.classList.remove('done'); delete btn.dataset.left; }
    let left = Number(btn.dataset.left || btn.dataset.sec);
    const tm = btn.querySelector('.tm');
    running = btn;
    btn.classList.add('run');
    tick = setInterval(() => {
      left -= 1;
      btn.dataset.left = left;
      tm.textContent = left > 0 ? fmt(left) : '時間です';
      if (left <= 0) { pauseTimer(); btn.classList.add('done'); }
    }, 1000);
  }

  // revealAll: show every step (used when moving backward into a slide)
  function show(i, revealAll) {
    i = Math.max(0, Math.min(last, i));
    if (cur >= 0) slides[cur].classList.remove('active');
    cur = i;
    const s = slides[i];
    setHl(s, '');
    frags(s).forEach(f => f.classList.toggle('shown', !!revealAll || showAll));
    void s.offsetWidth;
    s.classList.add('active');
    counter.textContent = i === 0 ? '表紙' : i + ' / ' + last;
    progress.style.width = (i / last * 100) + '%';
    if (location.hash !== '#' + i) history.replaceState(null, '', location.pathname + location.search + '#' + i);
  }
  function next() {
    const hidden = frags(slides[cur]).find(f => !f.classList.contains('shown'));
    if (hidden) hidden.classList.add('shown');
    else if (cur < last) show(cur + 1);
  }
  function prev() {
    const shown = frags(slides[cur]).filter(f => f.classList.contains('shown'));
    if (shown.length) shown[shown.length - 1].classList.remove('shown');
    else if (cur > 0) show(cur - 1, true);
  }
  // reveal steps in order up to and including el
  function revealTo(el) {
    for (const f of frags(slides[cur])) { f.classList.add('shown'); if (f === el) break; }
  }

  document.addEventListener('keydown', e => {
    const ctl = e.target.closest && e.target.closest('[data-hl-btn], .timer');
    if (ctl && (e.key === 'Enter' || e.key === ' ')) {
      if (ctl.tagName === 'BUTTON') return; // native click handles it
      e.preventDefault();
      setHl(slides[cur], ctl.dataset.hlBtn);
      return;
    }
    if (e.key === 'Escape') setHl(slides[cur], '');
    else if (['ArrowRight', 'PageDown'].includes(e.key) || (e.key === ' ' && !e.shiftKey)) { e.preventDefault(); next(); }
    else if (['ArrowLeft', 'PageUp'].includes(e.key) || (e.key === ' ' && e.shiftKey)) { e.preventDefault(); prev(); }
  });
  document.addEventListener('click', e => {
    if (e.button !== 0) return;
    const t = e.target.closest('[data-hl-btn], .timer, .ans.frag:not(.shown)');
    if (!t) return next();
    if (t.matches('.timer')) toggleTimer(t);
    else if (t.matches('[data-hl-btn]')) setHl(slides[cur], t.dataset.hlBtn);
    else revealTo(t);
    if (e.detail > 0 && t.blur) t.blur();
  });
  const fromHash = () => { const n = parseInt(location.hash.slice(1), 10); return Number.isInteger(n) ? n : 0; };
  window.addEventListener('hashchange', () => { const n = fromHash(); if (n !== cur) show(n); });
  show(fromHash());
})();
