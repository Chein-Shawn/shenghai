(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const language = () => window.vocaldiveI18n?.getLanguage?.() || document.documentElement.lang || 'en';
  const localText = element => {
    const key = String(language()).toLowerCase().startsWith('zh') ? 'zh' : 'en';
    return element.dataset[key] || element.textContent.trim();
  };

  function initFadingVideos() {
    document.querySelectorAll('[data-fading-video]').forEach(video => {
      video.muted = true;
      video.autoplay = true;
      video.playsInline = true;
      video.preload = 'auto';
      const configured = video.dataset.sources;
      const sources = configured ? JSON.parse(configured) : [video.getAttribute('src')].filter(Boolean);
      let sourceIndex = 0;
      const fadeIn = () => requestAnimationFrame(() => { video.style.opacity = '1'; });
      const fadeOut = () => { video.style.opacity = '0'; };
      const load = index => {
        sourceIndex = index % sources.length;
        if (video.src !== sources[sourceIndex]) video.src = sources[sourceIndex];
        video.load();
        video.play().catch(() => {});
      };
      video.addEventListener('loadeddata', fadeIn);
      video.addEventListener('timeupdate', () => {
        if (Number.isFinite(video.duration) && video.duration - video.currentTime <= .55) fadeOut();
      });
      video.addEventListener('ended', () => {
        fadeOut();
        window.setTimeout(() => {
          if (sources.length === 1) {
            video.currentTime = 0;
            video.play().catch(() => {});
          } else {
            load(sourceIndex + 1);
          }
          fadeIn();
        }, 560);
      });
      if (sources.length) load(0);
    });
  }

  function renderBlurText(element) {
    const text = localText(element);
    element.textContent = '';
    text.split(/\s+/).filter(Boolean).forEach((word, index) => {
      const span = document.createElement('span');
      span.className = 'blur-word';
      span.style.setProperty('--word-delay', `${index * 100}ms`);
      span.textContent = word;
      element.append(span);
    });
    const reveal = () => element.querySelectorAll('.blur-word').forEach(word => word.classList.add('is-visible'));
    if (reduceMotion || !('IntersectionObserver' in window)) return reveal();
    const observer = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) { reveal(); observer.unobserve(entry.target); }
    }), { threshold: .1 });
    observer.observe(element);
  }

  function initMotion() {
    const nodes = [...document.querySelectorAll('[data-motion]')];
    nodes.forEach(node => node.style.setProperty('--motion-delay', `${Number(node.dataset.delay || 0)}s`));
    const reveal = node => node.classList.add('is-visible');
    if (reduceMotion || !('IntersectionObserver' in window)) return nodes.forEach(reveal);
    const observer = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) { reveal(entry.target); observer.unobserve(entry.target); }
    }), { threshold: .1 });
    nodes.forEach(node => observer.observe(node));
  }

  function initProgress() {
    const bar = document.querySelector('.landing-progress span');
    const update = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = `${max > 0 ? Math.min(100, window.scrollY / max * 100) : 0}%`;
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
  }

  function initMenu() {
    const menu = document.querySelector('.landing-menu');
    const links = document.querySelector('.landing-nav-center');
    if (!menu || !links) return;
    menu.addEventListener('click', () => {
      const open = links.classList.toggle('is-open');
      menu.setAttribute('aria-expanded', String(open));
    });
    links.querySelectorAll('a').forEach(link => link.addEventListener('click', () => {
      links.classList.remove('is-open');
      menu.setAttribute('aria-expanded', 'false');
    }));
  }

  function initReferenceTone() {
    document.querySelectorAll('[data-landing-tone]').forEach(button => button.addEventListener('click', () => {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      const context = new AudioContext();
      const gain = context.createGain();
      const fundamental = context.createOscillator();
      const harmonic = context.createOscillator();
      const duration = 2.45;
      const frequency = Number(button.dataset.landingTone) || 523.25;
      gain.gain.setValueAtTime(.0001, context.currentTime);
      gain.gain.linearRampToValueAtTime(.11, context.currentTime + .09);
      gain.gain.setValueAtTime(.11, context.currentTime + 1.75);
      gain.gain.exponentialRampToValueAtTime(.0001, context.currentTime + duration);
      fundamental.type = 'sine'; fundamental.frequency.value = frequency;
      harmonic.type = 'sine'; harmonic.frequency.value = frequency * 2;
      const harmonicGain = context.createGain(); harmonicGain.gain.value = .075;
      fundamental.connect(gain).connect(context.destination);
      harmonic.connect(harmonicGain).connect(gain);
      fundamental.start(); harmonic.start();
      fundamental.stop(context.currentTime + duration); harmonic.stop(context.currentTime + duration);
      button.classList.add('is-playing');
      window.setTimeout(() => { button.classList.remove('is-playing'); context.close(); }, (duration + .12) * 1000);
    }));
  }

  document.addEventListener('DOMContentLoaded', () => {
    initFadingVideos();
    initMotion();
    initProgress();
    initMenu();
    initReferenceTone();
    document.querySelectorAll('[data-blur-text]').forEach(renderBlurText);
    window.addEventListener('vocaldive:languagechange', () => document.querySelectorAll('[data-blur-text]').forEach(renderBlurText));
  });
})();
