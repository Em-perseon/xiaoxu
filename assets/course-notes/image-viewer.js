(() => {
  const images = [...document.querySelectorAll('.course-note img[alt]')]
    .filter(image => image.alt.trim());
  if (!images.length) return;

  const dialog = document.createElement('dialog');
  dialog.className = 'course-image-viewer';
  dialog.setAttribute('aria-label', '查看图片大图');
  dialog.innerHTML = `
    <div class="course-image-toolbar">
      <span>图片大图</span>
      <button type="button" data-zoom aria-pressed="false">放大 2×</button>
      <button type="button" data-close aria-label="关闭大图">关闭 ×</button>
    </div>
    <div class="course-image-stage" tabindex="0" aria-label="图片区域，放大后可滚动查看">
      <img alt="">
    </div>
    <p class="course-image-caption"></p>`;
  document.body.append(dialog);
  const enlarged = dialog.querySelector('img');
  const stage = dialog.querySelector('.course-image-stage');
  const zoom = dialog.querySelector('[data-zoom]');
  const close = dialog.querySelector('[data-close]');
  const caption = dialog.querySelector('.course-image-caption');
  let trigger;
  let priorOverflow;

  function resetZoom() {
    zoom.setAttribute('aria-pressed', 'false');
    zoom.textContent = '放大 2×';
    enlarged.style.width = '';
    stage.classList.remove('is-zoomed');
    stage.scrollTo(0, 0);
  }

  for (const image of images) {
    if (image.closest('a, button')) continue;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'course-image-trigger';
    button.setAttribute('aria-label', `点击放大：${image.alt}`);
    button.setAttribute('aria-haspopup', 'dialog');
    button.title = '点击查看大图';
    image.replaceWith(button);
    button.append(image);
    button.addEventListener('click', () => {
      trigger = button;
      enlarged.src = image.currentSrc || image.src;
      enlarged.alt = image.alt;
      caption.textContent = image.alt;
      resetZoom();
      priorOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      dialog.showModal();
      close.focus();
    });
  }

  zoom.addEventListener('click', () => {
    if (zoom.getAttribute('aria-pressed') === 'true') return resetZoom();
    const fittedWidth = enlarged.getBoundingClientRect().width;
    stage.classList.add('is-zoomed');
    enlarged.style.width = `${fittedWidth * 2}px`;
    zoom.setAttribute('aria-pressed', 'true');
    zoom.textContent = '适应窗口';
  });
  close.addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener('close', () => {
    document.body.style.overflow = priorOverflow;
    resetZoom();
    trigger?.focus({ preventScroll: true });
  });
})();
