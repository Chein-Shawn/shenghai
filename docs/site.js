(() => {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function localizedValue(element, key) {
    const language = window.vocaldiveI18n ? window.vocaldiveI18n.getLanguage() : document.documentElement.lang;
    const suffix = String(language).toLowerCase().startsWith('zh') ? 'Zh' : 'En';
    return element.dataset[`${key}${suffix}`] || element.dataset[key] || element.textContent;
  }

  function updateScrollProgress() {
    const bar = document.querySelector('.site-progress span');
    if (!bar) return;
    const max = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.width = `${max > 0 ? Math.min(100, (window.scrollY / max) * 100) : 0}%`;
  }

  function initTelemetry() {
    const clocks = document.querySelectorAll('[data-live-clock]');
    if (!clocks.length) return;
    const update = () => {
      const now = new Date();
      const value = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
      clocks.forEach(clock => { clock.textContent = value; });
    };
    update();
    window.setInterval(update, 1000);
  }

  function initNavigation() {
    const menu = document.querySelector('.nav-menu');
    const links = document.querySelector('.nav-links');
    if (menu && links) menu.addEventListener('click', () => {
      const open = links.classList.toggle('is-open');
      menu.setAttribute('aria-expanded', String(open));
    });
  }

  function initReveal() {
    const nodes = document.querySelectorAll('.reveal');
    if (reduceMotion || !('IntersectionObserver' in window)) {
      nodes.forEach(node => node.classList.add('is-visible'));
      return;
    }
    const observer = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    }), { threshold: .14 });
    nodes.forEach(node => observer.observe(node));
  }

  function initToneButtons() {
    document.querySelectorAll('[data-tone]').forEach(button => button.addEventListener('click', () => {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      const context = new AudioContext();
      const oscillator = context.createOscillator();
      const harmonic = context.createOscillator();
      const harmonicGain = context.createGain();
      const gain = context.createGain();
      const frequency = Number(button.dataset.tone) || 440;
      const duration = Math.max(1.2, Number(button.dataset.toneDuration) || 2.1);
      if (context.state === 'suspended') context.resume();
      oscillator.type = 'sine';
      oscillator.frequency.value = frequency;
      harmonic.type = 'sine';
      harmonic.frequency.value = frequency * 2;
      harmonicGain.gain.value = .1;
      gain.gain.setValueAtTime(.0001, context.currentTime);
      gain.gain.linearRampToValueAtTime(.12, context.currentTime + .08);
      gain.gain.setValueAtTime(.12, context.currentTime + Math.max(.18, duration - .48));
      gain.gain.exponentialRampToValueAtTime(.0001, context.currentTime + duration);
      oscillator.connect(gain).connect(context.destination);
      harmonic.connect(harmonicGain).connect(gain);
      oscillator.start();
      harmonic.start();
      oscillator.stop(context.currentTime + duration + .03);
      harmonic.stop(context.currentTime + duration + .03);
      const original = button.textContent;
      button.textContent = button.dataset.playingLabel || 'Listening...';
      button.disabled = true;
      window.setTimeout(() => { button.textContent = original; button.disabled = false; context.close(); }, (duration + .15) * 1000);
    }));
  }

  function initVoiceCanvas() {
    const canvas = document.querySelector('[data-choir-canvas]');
    if (!canvas) return;
    const context = canvas.getContext('2d');
    const colors = ['#9af3d0', '#70d7f3', '#ff9b7d', '#f3ca75'];
    let activeVoice = 0;
    let start = performance.now();
    const resize = () => {
      const ratio = window.devicePixelRatio || 1;
      const rect = canvas.getBoundingClientRect();
      canvas.width = Math.max(1, rect.width * ratio);
      canvas.height = Math.max(1, rect.height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    };
    const draw = now => {
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      const elapsed = (now - start) / 1000;
      context.clearRect(0, 0, width, height);
      context.fillStyle = '#091922';
      context.fillRect(0, 0, width, height);
      context.strokeStyle = 'rgba(244,247,242,.14)';
      context.lineWidth = 1;
      for (let line = 1; line <= 5; line += 1) {
        const y = height * (.33 + line * .065);
        context.beginPath(); context.moveTo(0, y); context.lineTo(width, y); context.stroke();
      }
      colors.forEach((color, index) => {
        context.strokeStyle = color;
        context.globalAlpha = index === activeVoice ? .98 : .3;
        context.lineWidth = index === activeVoice ? 3 : 1.5;
        context.beginPath();
        for (let x = 0; x <= width; x += 5) {
          const progress = x / width;
          const base = height * (.28 + index * .115);
          const wave = Math.sin(progress * 13 + elapsed * (1.1 + index * .12)) * 7;
          const phrase = Math.sin(progress * 4.2 + index) * 10;
          const y = base + wave + phrase;
          if (x === 0) context.moveTo(x, y); else context.lineTo(x, y);
        }
        context.stroke();
      });
      context.globalAlpha = 1;
      const playhead = (elapsed * 70) % Math.max(1, width);
      context.strokeStyle = 'rgba(244,247,242,.72)';
      context.lineWidth = 1;
      context.beginPath(); context.moveTo(playhead, height * .12); context.lineTo(playhead, height * .86); context.stroke();
      if (!reduceMotion) requestAnimationFrame(draw);
    };
    window.addEventListener('resize', resize);
    resize();
    draw(performance.now());
    document.querySelectorAll('[data-voice]').forEach(button => button.addEventListener('click', () => {
      activeVoice = Number(button.dataset.voice) || 0;
      document.querySelectorAll('[data-voice]').forEach(item => item.classList.toggle('active', item === button));
      const status = document.querySelector('[data-voice-status]');
      if (status) status.textContent = localizedValue(button, 'voiceLabel');
    }));
  }

  function initLoop() {
    const steps = [...document.querySelectorAll('[data-loop-step]')];
    const title = document.querySelector('[data-loop-title]');
    const body = document.querySelector('[data-loop-body]');
    const bars = document.querySelector('[data-signal-bars]');
    if (!steps.length || !title || !body) return;
    steps.forEach((step, index) => step.addEventListener('click', () => {
      steps.forEach(item => item.classList.remove('active'));
      step.classList.add('active');
      title.textContent = localizedValue(step, 'loopTitle');
      body.textContent = localizedValue(step, 'loopBody');
      if (bars) bars.dataset.phase = String(index);
    }));
    window.addEventListener('vocaldive:languagechange', () => {
      const active = steps.find(step => step.classList.contains('active')) || steps[0];
      title.textContent = localizedValue(active, 'loopTitle');
      body.textContent = localizedValue(active, 'loopBody');
    });
  }

  function initFilters() {
    const entries = [...document.querySelectorAll('[data-entry-kind]')];
    document.querySelectorAll('[data-filter]').forEach(button => button.addEventListener('click', () => {
      const filter = button.dataset.filter;
      document.querySelectorAll('[data-filter]').forEach(item => item.classList.toggle('active', item === button));
      entries.forEach(entry => { entry.hidden = filter !== 'all' && entry.dataset.entryKind !== filter; });
    }));
  }

  window.addEventListener('scroll', updateScrollProgress, { passive: true });
  window.addEventListener('resize', updateScrollProgress);
  document.addEventListener('DOMContentLoaded', () => {
    updateScrollProgress();
    initTelemetry();
    initNavigation();
    initReveal();
    initToneButtons();
    initVoiceCanvas();
    initLoop();
    initFilters();
  });
})();
