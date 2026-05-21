/* ── Header navigation ── */
(function(){
  const hamburger = document.getElementById('hamburger');
  const nav = document.getElementById('main-nav');
  if (!hamburger || !nav) return;

  hamburger.addEventListener('click', () => {
    hamburger.classList.toggle('open');
    nav.classList.toggle('open');
  });

  // Mobile accordion toggle
  document.querySelectorAll('.nav-dropdown > a').forEach(link => {
    link.addEventListener('click', (e) => {
      if (window.innerWidth <= 900) {
        e.preventDefault();
        const dropdown = link.nextElementSibling;
        if (!dropdown) return;
        const arrow = link.querySelector('.dropdown-arrow');
        const isOpen = dropdown.classList.contains('open');
        // Close all others
        document.querySelectorAll('.dropdown-menu.open, .mega-menu.open').forEach(d => d.classList.remove('open'));
        document.querySelectorAll('.nav-dropdown > a .dropdown-arrow').forEach(a => a.style.transform = '');
        // Toggle current
        if (!isOpen) {
          dropdown.classList.add('open');
          if (arrow) arrow.style.transform = 'rotate(180deg)';
        }
      }
    });
  });
})();

/* ── Scroll top btn ── */
const flTop = document.getElementById('flTop');
if (flTop) {
  flTop.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  window.addEventListener('scroll', () => {
    flTop.style.opacity = window.scrollY > 400 ? '1' : '0';
    flTop.style.pointerEvents = window.scrollY > 400 ? 'auto' : 'none';
  });
}

/* ── News row links ── */
document.querySelectorAll('.news-row[data-href]').forEach(row => {
  row.addEventListener('click', () => {
    window.location.href = row.dataset.href;
  });
});

/* ── Clinic environment carousel ── */
(function(){
  const carousel = document.querySelector('.clinic-env-carousel');
  const track = document.querySelector('.clinic-env-track');
  if (!carousel || !track) return;
  const prevBtn = document.querySelector('.clinic-env-prev');
  const nextBtn = document.querySelector('.clinic-env-next');
  const dots = Array.from(document.querySelectorAll('.clinic-env-dots button'));

  const originalCount = track.querySelectorAll('.clinic-env-card:not([aria-hidden="true"])').length;
  let current = 0;
  let timer;
  let isInView = false;

  function getGap(){
    return parseFloat(getComputedStyle(track).gap) || 0;
  }

  function slideWidth(){
    const first = track.querySelector('.clinic-env-card');
    if (!first) return 0;
    return first.getBoundingClientRect().width + getGap();
  }

  function moveTo(index, animate = true){
    track.style.transition = animate ? 'transform .5s ease' : 'none';
    track.style.transform = `translateX(-${slideWidth() * index}px)`;
    updateDots(index);
  }

  function updateDots(index){
    if (!dots.length) return;
    const active = ((index % originalCount) + originalCount) % originalCount;
    dots.forEach((dot, dotIndex) => {
      dot.classList.toggle('is-active', dotIndex === active);
    });
  }

  function next(){
    current += 1;
    moveTo(current);

    if (current >= originalCount) {
      window.setTimeout(() => {
        current = 0;
        moveTo(current, false);
      }, 520);
    }
  }

  function prev(){
    if (current <= 0) {
      current = originalCount;
      moveTo(current, false);
      window.requestAnimationFrame(() => {
        current -= 1;
        moveTo(current);
      });
      return;
    }

    current -= 1;
    moveTo(current);
  }

  function stop(){
    clearInterval(timer);
    timer = null;
  }

  function restart(){
    if (!isInView) return;
    stop();
    timer = window.setInterval(next, 2000);
  }

  window.addEventListener('resize', () => moveTo(current, false));
  carousel.addEventListener('mouseenter', stop);
  carousel.addEventListener('mouseleave', restart);
  if (prevBtn) {
    prevBtn.addEventListener('click', () => {
      prev();
      restart();
    });
  }
  if (nextBtn) {
    nextBtn.addEventListener('click', () => {
      next();
      restart();
    });
  }
  dots.forEach((dot, dotIndex) => {
    dot.addEventListener('click', () => {
      current = dotIndex;
      moveTo(current);
      restart();
    });
  });

  moveTo(0, false);
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      const entry = entries[0];
      isInView = entry.isIntersecting;
      if (isInView) {
        restart();
      } else {
        stop();
      }
    }, { threshold: 0.25 });
    observer.observe(carousel);
  } else {
    const checkVisibility = () => {
      const rect = carousel.getBoundingClientRect();
      isInView = rect.top < window.innerHeight && rect.bottom > 0;
      if (isInView) {
        restart();
      } else {
        stop();
      }
    };
    window.addEventListener('scroll', checkVisibility, { passive: true });
    window.addEventListener('resize', checkVisibility);
    checkVisibility();
  }
})();

/* ── Services carousel (6 per page desktop, 2 tablet, 1 mobile) ── */
(function(){
  const track    = document.getElementById('svcTrack');
  const dotsWrap = document.getElementById('svcDots');
  const prevBtn  = document.getElementById('svcPrev');
  const nextBtn  = document.getElementById('svcNext');
  if (!track || !dotsWrap || !prevBtn || !nextBtn) return;

  const cards    = Array.from(track.querySelectorAll('.svc-card'));
  const total    = cards.length;
  let cur = 0;

  function isMobileGrid() {
    return window.innerWidth <= 600;
  }

  function perView() {
    if (window.innerWidth < 600) return 1;
    if (window.innerWidth < 900) return 2;
    return 6;
  }

  function cardW() {
    const c = track.querySelector('.svc-card');
    if (!c) return 0;
    const style = getComputedStyle(c);
    return c.getBoundingClientRect().width + parseFloat(style.marginLeft) + parseFloat(style.marginRight);
  }

  function pages() { return Math.ceil(total / perView()); }

  function buildDots() {
    dotsWrap.innerHTML = '';
    if (isMobileGrid()) return;
    for (let i = 0; i < pages(); i++) {
      const b = document.createElement('button');
      b.className = 'svc-dot' + (i === cur ? ' active' : '');
      b.setAttribute('aria-label', `第 ${i+1} 頁`);
      b.addEventListener('click', () => goTo(i));
      dotsWrap.appendChild(b);
    }
  }

  function goTo(idx) {
    if (isMobileGrid()) {
      cur = 0;
      track.style.transform = 'none';
      prevBtn.disabled = true;
      nextBtn.disabled = true;
      return;
    }
    cur = Math.max(0, Math.min(idx, pages() - 1));
    track.style.transform = `translateX(-${cur * perView() * cardW()}px)`;
    dotsWrap.querySelectorAll('.svc-dot').forEach((d, i) => d.classList.toggle('active', i === cur));
    prevBtn.disabled = cur <= 0;
    nextBtn.disabled = cur >= pages() - 1;
  }

  prevBtn.addEventListener('click', () => goTo(cur - 1));
  nextBtn.addEventListener('click', () => goTo(cur + 1));

  // Touch swipe
  let sx = 0;
  track.addEventListener('touchstart', e => { sx = e.touches[0].clientX; }, { passive: true });
  track.addEventListener('touchend', e => {
    const dx = e.changedTouches[0].clientX - sx;
    if (Math.abs(dx) > 50) dx < 0 ? goTo(cur + 1) : goTo(cur - 1);
  });

  window.addEventListener('resize', () => { buildDots(); goTo(0); });
  buildDots();
  goTo(0);
})();

/* ── Google reviews carousel ── */
(function(){
  const track = document.getElementById('googleReviewsTrack');
  const prevBtn = document.getElementById('googleReviewPrev');
  const nextBtn = document.getElementById('googleReviewNext');
  if (!track || !prevBtn || !nextBtn) return;

  const cards = Array.from(track.querySelectorAll('.google-review-card'));
  const total = cards.length;
  let cur = 0;

  function perView() {
    if (window.innerWidth < 600) return 1;
    if (window.innerWidth < 900) return 2;
    return 3;
  }

  function maxIndex() {
    return Math.max(0, total - perView());
  }

  function stepW() {
    const c = cards[0];
    if (!c) return 0;
    const style = getComputedStyle(track);
    return c.getBoundingClientRect().width + parseFloat(style.columnGap || style.gap || 0);
  }

  function goTo(idx) {
    cur = Math.max(0, Math.min(idx, maxIndex()));
    track.style.transform = `translateX(-${cur * stepW()}px)`;
  }

  prevBtn.addEventListener('click', () => goTo(cur <= 0 ? maxIndex() : cur - 1));
  nextBtn.addEventListener('click', () => goTo(cur >= maxIndex() ? 0 : cur + 1));

  window.addEventListener('resize', () => {
    cur = Math.min(cur, maxIndex());
    goTo(cur);
  });

  goTo(0);
})();

/* ── International exchange carousel ── */
(function(){
  const track = document.getElementById('exchangeTrack');
  const dotsWrap = document.getElementById('exchangeDots');
  const prevBtn = document.getElementById('exchangePrev');
  const nextBtn = document.getElementById('exchangeNext');
  if (!track || !dotsWrap || !prevBtn || !nextBtn) return;

  const cards = Array.from(track.querySelectorAll('.exchange-card'));
  const total = cards.length;
  let cur = 0;
  let timer;

  function perView() {
    if (window.innerWidth < 600) return 1;
    if (window.innerWidth < 900) return 2;
    return 3;
  }

  function maxIndex() {
    return Math.max(0, total - perView());
  }

  function stepW() {
    const c = cards[0];
    if (!c) return 0;
    const style = getComputedStyle(track);
    return c.getBoundingClientRect().width + parseFloat(style.columnGap || style.gap || 0);
  }

  function buildDots() {
    dotsWrap.innerHTML = '';
    for (let i = 0; i <= maxIndex(); i++) {
      const dot = document.createElement('button');
      dot.className = 'exchange-dot' + (i === cur ? ' active' : '');
      dot.setAttribute('aria-label', `國際交流第 ${i + 1} 組`);
      dot.addEventListener('click', () => {
        goTo(i);
        restart();
      });
      dotsWrap.appendChild(dot);
    }
  }

  function goTo(idx) {
    cur = Math.max(0, Math.min(idx, maxIndex()));
    track.style.transform = `translateX(-${cur * stepW()}px)`;
    dotsWrap.querySelectorAll('.exchange-dot').forEach((dot, i) => dot.classList.toggle('active', i === cur));
  }

  function next() {
    goTo(cur >= maxIndex() ? 0 : cur + 1);
  }

  function prev() {
    goTo(cur <= 0 ? maxIndex() : cur - 1);
  }

  function restart() {
    clearInterval(timer);
    timer = setInterval(next, 4200);
  }

  prevBtn.addEventListener('click', () => {
    prev();
    restart();
  });

  nextBtn.addEventListener('click', () => {
    next();
    restart();
  });

  window.addEventListener('resize', () => {
    cur = Math.min(cur, maxIndex());
    buildDots();
    goTo(cur);
    restart();
  });

  buildDots();
  goTo(0);
  restart();
})();

/* ── Cases fullbleed carousel ── */
(function(){
  const track   = document.getElementById('casesTrack');
  const dotsWrap= document.getElementById('cDots');
  const prevBtn = document.getElementById('cPrev');
  const nextBtn = document.getElementById('cNext');
  const counter = document.getElementById('casesCounter');
  if (!track || !dotsWrap || !prevBtn || !nextBtn) return;

  const slides  = Array.from(track.querySelectorAll('.case-slide'));
  const total   = slides.length;
  let cur = 0;
  let timer;

  function buildDots(){
    dotsWrap.innerHTML = '';
    slides.forEach((_, i) => {
      const b = document.createElement('button');
      b.className = 'c-dot' + (i === cur ? ' active' : '');
      b.setAttribute('aria-label', `第${i+1}張`);
      b.addEventListener('click', () => {
        goTo(i);
        restart();
      });
      dotsWrap.appendChild(b);
    });
  }

  function goTo(idx){
    cur = Math.max(0, Math.min(idx, total - 1));
    track.style.transform = `translateX(-${cur * 100}%)`;
    dotsWrap.querySelectorAll('.c-dot').forEach((d,i) => d.classList.toggle('active', i === cur));
    if (counter) counter.textContent = `${cur + 1} / ${total}`;
    prevBtn.disabled = cur <= 0;
    nextBtn.disabled = cur >= total - 1;
  }

  function next(){
    goTo(cur >= total - 1 ? 0 : cur + 1);
  }

  function restart(){
    clearInterval(timer);
    timer = setInterval(next, 5000);
  }

  prevBtn.addEventListener('click', () => {
    goTo(cur - 1);
    restart();
  });
  nextBtn.addEventListener('click', () => {
    next();
    restart();
  });

  // Touch swipe
  let sx = 0;
  track.addEventListener('touchstart', e => { sx = e.touches[0].clientX; }, { passive: true });
  track.addEventListener('touchend',   e => {
    const dx = e.changedTouches[0].clientX - sx;
    if (Math.abs(dx) > 50) {
      dx < 0 ? next() : goTo(cur - 1);
      restart();
    }
  });

  // Keyboard
  document.addEventListener('keydown', e => {
    if (e.key === 'ArrowLeft') {
      goTo(cur - 1);
      restart();
    }
    if (e.key === 'ArrowRight') {
      next();
      restart();
    }
  });

  buildDots();
  goTo(0);
  restart();
})();
