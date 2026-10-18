const slides = [...document.querySelectorAll('.slide')];
let index = Math.min(slides.length - 1, Math.max(0, Number(location.hash.slice(1)) - 1 || 0));
const notes = document.querySelector('#notes');
const notesToggle = document.querySelector('#notes-toggle');
function show(next) {
  index = Math.min(slides.length - 1, Math.max(0, next));
  slides.forEach((slide, i) => { slide.classList.toggle('active', i === index); slide.setAttribute('aria-hidden', String(i !== index)); });
  document.querySelector('#position').textContent = `${index + 1} / ${slides.length}`;
  notes.textContent = slides[index].dataset.notes;
  history.replaceState(null, '', `#${index + 1}`);
  document.querySelector('#previous').disabled = index === 0;
  document.querySelector('#next').disabled = index === slides.length - 1;
}
function resize() { document.documentElement.style.setProperty('--scale', Math.min(innerWidth / 1440, (innerHeight - 48) / 810)); }
function toggleNotes() { notes.hidden = !notes.hidden; notesToggle.setAttribute('aria-expanded', String(!notes.hidden)); }
function fullscreen() { if (document.fullscreenElement) document.exitFullscreen(); else document.documentElement.requestFullscreen?.().catch(() => {}); }
document.querySelector('#previous').onclick = () => show(index - 1);
document.querySelector('#next').onclick = () => show(index + 1);
notesToggle.onclick = toggleNotes;
document.querySelector('#fullscreen').onclick = fullscreen;
let motionOff = matchMedia('(prefers-reduced-motion: reduce)').matches;
function motion() {
  document.querySelector('.architecture-diagram').src = `architecture.svg${motionOff ? '#still' : ''}`;
  document.querySelector('#motion').textContent = `Animación: ${motionOff ? 'pausada' : 'activa'}`;
  document.querySelector('#motion').setAttribute('aria-pressed', String(motionOff));
}
document.querySelector('#motion').onclick = () => { motionOff = !motionOff; motion(); };
addEventListener('keydown', event => {
  if (['ArrowRight', 'PageDown', ' '].includes(event.key)) { event.preventDefault(); show(index + 1); }
  if (['ArrowLeft', 'PageUp'].includes(event.key)) { event.preventDefault(); show(index - 1); }
  if (event.key === 'Home') show(0);
  if (event.key === 'End') show(slides.length - 1);
  if (event.key.toLowerCase() === 'n') toggleNotes();
  if (event.key.toLowerCase() === 'f') fullscreen();
  if (event.key.toLowerCase() === 'd') window.open('https://verifica.deepskill.space/', '_blank', 'noopener,noreferrer');
});
addEventListener('resize', resize); resize(); show(index); motion();
