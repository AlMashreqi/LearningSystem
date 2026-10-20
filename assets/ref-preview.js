/* ============================================================
   Hover-preview windows for cross-lesson citations.

   Used by any lesson whose citation links carry class="ref" and a
   href of the form "file.html#id" pointing at an anchored statement
   in another lesson (see the study-materials format guide).

   Behaviour:
   - Hover (or keyboard focus) a .ref link -> the WHOLE target page
     loads inside a 9:16 window, in the left or right margin only
     (never overlapping or dropping below the text column). The
     browser's own #id navigation scrolls it straight to the cited
     statement, and shared CSS (:target, in style.css) highlights
     that exact element automatically -- no cross-frame JS needed.
   - If neither margin has room for the window, nothing is shown on
     hover; the link still navigates normally on click.
   - Moving the pointer into the window keeps it open.
   - Click on the original link still navigates normally.
   ============================================================ */

(function () {
  var RATIO = 16 / 9;        // height / width  (9:16 portrait window)
  var MIN_GUTTER = 190;      // px of clear margin required to show at all
  var MIN_WIDTH = 150;       // px -- below this, don't bother showing
  var MARGIN = 14;           // px kept clear from the viewport edge
  var SHOW_DELAY = 130;
  var HIDE_DELAY = 240;

  function boot() {
    var wrap = document.querySelector('.wrap');
    var refs = document.querySelectorAll('a.ref[href]');
    if (!refs.length) return;

    var card = document.createElement('div');
    card.className = 'ref-card';
    card.hidden = true;
    card.innerHTML =
      '<div class="rc-bar">' +
        '<span class="rc-label"></span>' +
        '<a class="rc-open" target="_top">open full page ↗</a>' +
      '</div>' +
      '<div class="rc-frame-wrap"><iframe class="ref-frame" loading="lazy"></iframe></div>';
    document.body.appendChild(card);

    var labelEl = card.querySelector('.rc-label');
    var openEl = card.querySelector('.rc-open');
    var frameEl = card.querySelector('.ref-frame');

    var showTimer = null, hideTimer = null, current = null, lastSrc = null;

    function labelFor(href) {
      var m = href.match(/(\d{4})[^/]*\.html/);
      return m ? 'Lesson ' + m[1] : href.split('#')[0];
    }

    function fits(a) {
      var wr = wrap ? wrap.getBoundingClientRect() : { left: 0, right: window.innerWidth };
      var leftGutter = wr.left;
      var rightGutter = window.innerWidth - wr.right;
      var side = rightGutter >= leftGutter ? 'right' : 'left';
      var gutter = Math.max(leftGutter, rightGutter);
      if (gutter < MIN_GUTTER) return null;

      // fill the whole gutter -- no upper cap, just the room that's actually there
      var width = Math.max(MIN_WIDTH, gutter - MARGIN * 2);
      var height = width * RATIO;
      var availableH = window.innerHeight - MARGIN * 2;
      if (height > availableH) {
        height = availableH;
        width = height / RATIO;
        if (width < MIN_WIDTH) return null;
      }
      return { side: side, width: width, height: height, wr: wr, leftGutter: leftGutter, rightGutter: rightGutter };
    }

    function place(a, geo) {
      var lr = a.getBoundingClientRect();
      var x = geo.side === 'right'
        ? geo.wr.right + (geo.rightGutter - geo.width) / 2
        : geo.wr.left - (geo.leftGutter + geo.width) / 2;
      x = Math.max(MARGIN, Math.min(x, window.innerWidth - geo.width - MARGIN));

      var y = lr.top - geo.height / 3;
      var maxY = window.innerHeight - geo.height - MARGIN;
      y = Math.max(MARGIN, Math.min(y, Math.max(MARGIN, maxY)));

      card.style.width = geo.width + 'px';
      card.style.height = geo.height + 'px';
      card.style.left = x + 'px';
      card.style.top = y + 'px';
    }

    function navigateFrame(href) {
      // Force a fresh navigation every time, even to the same href: this is
      // what makes the browser actually run its "scroll to #id" behaviour.
      // Also -- critically -- this only works reliably once the iframe has
      // a real, laid-out box, which is why it happens AFTER the card is
      // shown and sized, never before.
      frameEl.src = 'about:blank';
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          frameEl.src = href;
          lastSrc = href;
        });
      });
    }

    function show(a) {
      var geo = fits(a);
      if (!geo) return; // no room in either margin -- click still works, no preview
      var href = a.getAttribute('href');
      clearTimeout(hideTimer); clearTimeout(showTimer);
      showTimer = setTimeout(function () {
        current = a;
        labelEl.textContent = labelFor(href);
        openEl.setAttribute('href', href);
        card.hidden = false;
        place(a, geo);
        navigateFrame(href);
      }, SHOW_DELAY);
    }

    function scheduleHide() {
      clearTimeout(showTimer); clearTimeout(hideTimer);
      hideTimer = setTimeout(function () {
        card.hidden = true;
        current = null;
      }, HIDE_DELAY);
    }
    function cancelHide() { clearTimeout(hideTimer); }

    Array.prototype.forEach.call(refs, function (a) {
      a.addEventListener('mouseenter', function () { show(a); });
      a.addEventListener('mouseleave', scheduleHide);
      a.addEventListener('focus', function () { show(a); });
      a.addEventListener('blur', scheduleHide);
    });
    card.addEventListener('mouseenter', cancelHide);
    card.addEventListener('mouseleave', scheduleHide);

    window.addEventListener('scroll', function () {
      if (current && !card.hidden) { var g = fits(current); if (g) place(current, g); else card.hidden = true; }
    }, { passive: true });
    window.addEventListener('resize', function () {
      if (current && !card.hidden) { var g = fits(current); if (g) place(current, g); else card.hidden = true; }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
