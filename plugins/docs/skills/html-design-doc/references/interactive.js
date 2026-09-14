/* html-design-doc — 手順D interaction script.
   Inline this verbatim as the first element child of <body>, inside one
   of the document's two permitted script elements. Display switching
   only: no fetch, no storage, no globals. */
(function () {
  'use strict';

  document.body.classList.add('js');

  function panelOf(tab) {
    return document.getElementById(tab.getAttribute('aria-controls'));
  }

  /* Tabs of this group only: a tab nested in an inner [data-tabs]
     belongs to that inner group, and a tab whose aria-controls names
     no element is ignored so it can never hide every panel. */
  function tabsOf(group) {
    return [].slice.call(group.querySelectorAll('[role="tab"]')).filter(
      function (t) {
        return t.closest('[data-tabs]') === group && panelOf(t);
      }
    );
  }

  function select(tab, focus) {
    var group = tab.closest('[data-tabs]');
    if (!group) return false;
    var tabs = tabsOf(group);
    if (tabs.indexOf(tab) < 0) return false;
    tabs.forEach(function (t) {
      var on = t === tab;
      t.setAttribute('aria-selected', on ? 'true' : 'false');
      t.tabIndex = on ? 0 : -1;
      panelOf(t).hidden = !on;
    });
    if (focus) tab.focus();
    return true;
  }

  function initGroup(group) {
    var list = group.querySelector('[role="tablist"]');
    if (list && list.closest('[data-tabs]') === group) list.hidden = false;
    var tabs = tabsOf(group);
    if (!tabs.length) return;
    var preferred = tabs.filter(function (t) {
      return panelOf(t).hasAttribute('data-default');
    })[0];
    select(preferred || tabs[0], false);
  }

  /* Arrow keys are the tablist pattern, so they apply only inside a
     horizontal [role="tablist"] that belongs to a tab group. */
  function tablistOf(tab) {
    var list = tab.closest('[role="tablist"]');
    if (!list || !list.closest('[data-tabs]')) return null;
    var axis = list.getAttribute('aria-orientation');
    return !axis || axis === 'horizontal' ? list : null;
  }

  function move(tab, key) {
    var list = tablistOf(tab);
    if (!list) return false;
    var tabs = tabsOf(list.closest('[data-tabs]'));
    var i = tabs.indexOf(tab);
    if (i < 0) return false;
    if (key === 'ArrowRight') i = (i + 1) % tabs.length;
    else if (key === 'ArrowLeft') i = (i - 1 + tabs.length) % tabs.length;
    else if (key === 'Home') i = 0;
    else if (key === 'End') i = tabs.length - 1;
    else return false;
    return select(tabs[i], true);
  }

  /* An anchor may point inside panels the reader cannot see, possibly
     nested. Open them outermost first, then jump. */
  function openPanels(target) {
    var chain = [];
    var el = target.closest('.iv-tabpanel[hidden]');
    while (el) {
      chain.unshift(el);
      el = el.parentElement && el.parentElement.closest('.iv-tabpanel[hidden]');
    }
    chain.forEach(function (panel) {
      var tab = document.getElementById(panel.getAttribute('aria-labelledby'));
      if (tab) select(tab, false);
    });
  }

  function reveal(hash) {
    if (!hash || hash.length < 2) return;
    var id;
    try {
      id = decodeURIComponent(hash.slice(1));
    } catch (err) {
      return; /* malformed percent-encoding: nothing to reveal */
    }
    var target = document.getElementById(id);
    if (!target || !target.closest) return;
    openPanels(target);
    target.scrollIntoView();
  }

  function eachDetails(selector, fn) {
    [].forEach.call(document.querySelectorAll(selector), fn);
  }

  document.addEventListener('click', function (e) {
    if (!e.target.closest) return;
    var tab = e.target.closest('[role="tab"]');
    if (tab && select(tab, true)) {
      e.preventDefault();
      return;
    }
    var link = e.target.closest('a[href^="#"]');
    if (link) reveal(link.getAttribute('href'));
  });

  document.addEventListener('keydown', function (e) {
    if (!e.target.closest) return;
    var tab = e.target.closest('[role="tab"]');
    if (tab && move(tab, e.key)) e.preventDefault();
  });

  window.addEventListener('hashchange', function () {
    reveal(location.hash);
  });

  /* Closed <details> cannot be forced open from CSS, so paper
     output needs this pair. */
  window.addEventListener('beforeprint', function () {
    eachDetails('details[data-collapsible]:not([open])', function (d) {
      d.setAttribute('data-was-closed', '');
      d.open = true;
    });
  });

  window.addEventListener('afterprint', function () {
    eachDetails('details[data-was-closed]', function (d) {
      d.removeAttribute('data-was-closed');
      d.open = false;
    });
  });

  /* iv-ready must land even if wiring throws, or the CSS gate would
     leave every non-default panel hidden with no way to open it. */
  function start() {
    try {
      [].forEach.call(document.querySelectorAll('[data-tabs]'), initGroup);
    } finally {
      document.body.classList.add('iv-ready');
    }
    reveal(location.hash);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
