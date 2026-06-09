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

/* ── Knowledge category filters ── */
(function(){
  const tabs = Array.from(document.querySelectorAll('.knowledge-filter-tab'));
  const cards = Array.from(document.querySelectorAll('.knowledge-card[data-knowledge-category]'));
  if (!tabs.length || !cards.length) return;

  function applyFilter(filter){
    tabs.forEach(tab => {
      const isActive = tab.dataset.knowledgeFilter === filter;
      tab.classList.toggle('is-active', isActive);
      tab.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });

    cards.forEach(card => {
      const categories = (card.dataset.knowledgeCategory || '').split(/\s+/);
      const shouldShow = filter === 'all' || categories.includes(filter);
      card.classList.toggle('is-hidden', !shouldShow);
    });
  }

  tabs.forEach(tab => {
    tab.setAttribute('aria-pressed', tab.classList.contains('is-active') ? 'true' : 'false');
    tab.addEventListener('click', () => applyFilter(tab.dataset.knowledgeFilter || 'all'));
  });
})();

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

/* ── Partner carousel ── */
(function(){
  const track = document.getElementById('partnerTrack');
  const dotsWrap = document.getElementById('partnerDots');
  if (!track || !dotsWrap) return;

  const logos = Array.from(track.querySelectorAll('.partner-logo'));
  const total = logos.length;
  let cur = 0;
  let timer;

  function perPage() {
    return window.innerWidth < 600 ? 2 : 4;
  }

  function pages() {
    return Math.ceil(total / perPage());
  }

  function stepW() {
    const first = logos[0];
    if (!first) return 0;
    const style = getComputedStyle(track);
    return first.getBoundingClientRect().width + parseFloat(style.columnGap || style.gap || 0);
  }

  function buildDots() {
    dotsWrap.innerHTML = '';
    for (let i = 0; i < pages(); i++) {
      const dot = document.createElement('button');
      dot.className = 'partner-dot' + (i === cur ? ' active' : '');
      dot.setAttribute('aria-label', `合作夥伴第 ${i + 1} 頁`);
      dot.addEventListener('click', () => goTo(i));
      dotsWrap.appendChild(dot);
    }
  }

  function goTo(idx) {
    cur = Math.max(0, Math.min(idx, pages() - 1));
    track.style.transform = `translateX(-${cur * perPage() * stepW()}px)`;
    dotsWrap.querySelectorAll('.partner-dot').forEach((dot, i) => dot.classList.toggle('active', i === cur));
  }

  function next() {
    goTo(cur >= pages() - 1 ? 0 : cur + 1);
  }

  function start() {
    clearInterval(timer);
    timer = setInterval(next, 3200);
  }

  function stop() {
    clearInterval(timer);
  }

  let sx = 0;
  track.addEventListener('touchstart', e => { sx = e.touches[0].clientX; }, { passive: true });
  track.addEventListener('touchend', e => {
      const dx = e.changedTouches[0].clientX - sx;
      if (Math.abs(dx) > 50) dx < 0 ? goTo(cur + 1) : goTo(cur - 1);
      start();
  });

  window.addEventListener('resize', () => {
    cur = Math.min(cur, pages() - 1);
    buildDots();
    goTo(cur);
  });

  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => entry.isIntersecting ? start() : stop());
    }, { threshold: .35 });
    observer.observe(track.closest('.partner-sec') || track);
  } else {
    start();
  }

  buildDots();
  goTo(0);
})();
