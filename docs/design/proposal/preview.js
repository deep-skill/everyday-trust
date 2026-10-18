const examples = {
  relative: {
    text: 'Hola mamá, cambié de número. Necesito que me hagas una transferencia urgente. Te cuento después.',
    label: 'Sospechoso',
    title: 'Confirma quién te escribe antes de enviar dinero.',
    summary: 'El mensaje combina un cambio de número con un pedido urgente de dinero. Eso merece una comprobación por otro canal; el texto no permite confirmar quién escribe.',
    actionTitle: 'Contacta a tu familiar por otro canal.',
    actionCopy: 'Llama al número que ya tenías guardado. No uses un nuevo contacto que te envíen en este mismo mensaje.',
    signals: ['El texto dice que la persona cambió de número.', 'Pide una transferencia urgente.', 'La identidad del remitente no está comprobada.'],
    interpretation: true
  },
  bank: {
    text: 'BANCO EJEMPLO: Tu cuenta será bloqueada hoy. Valida tu contraseña en https://acceso-banco.example/validar para evitar el bloqueo.',
    label: 'Alto riesgo',
    title: 'Te pide una contraseña con amenaza de bloqueo.',
    summary: 'La solicitud de una contraseña y la presión para actuar son señales de riesgo en este ejemplo. No ingreses tus claves en el enlace recibido.',
    actionTitle: 'Abre la app de tu banco por tu cuenta.',
    actionCopy: 'Revisa los avisos desde la app que ya utilizas. Si necesitas ayuda, busca el contacto en esa app o en tu tarjeta.',
    signals: ['El mensaje solicita una contraseña.', 'Anuncia un bloqueo inmediato para presionar.', 'Banco Ejemplo y el dominio .example son ficticios; no hay una comprobación contra un banco real.'],
    interpretation: false
  }
};

const message = document.querySelector('#message');
const feedback = document.querySelector('#preview-feedback');
const dialog = document.querySelector('#info-dialog');
const selectedInteractions = new Set();

function updateInput() {
  document.querySelector('#character-count').textContent = `${message.value.length.toLocaleString('es-PE')} / 5.000`;
  document.querySelector('#review-button').disabled = !message.value.trim();
}

function reset() {
  document.querySelector('#entry').hidden = false;
  document.querySelector('#case').hidden = true;
  feedback.hidden = true;
  message.value = '';
  updateInput();
  selectedInteractions.clear();
  document.querySelectorAll('[data-interaction]').forEach(button => button.setAttribute('aria-pressed', 'false'));
  document.querySelector('#follow-up').hidden = true;
  document.querySelector('.evidence').open = false;
  window.scrollTo({ top: 0, behavior: 'instant' });
  message.focus({ preventScroll: true });
}

function showExample(key) {
  const example = examples[key];
  document.querySelector('#entry').hidden = true;
  document.querySelector('#case').hidden = false;
  feedback.hidden = true;
  document.querySelector('#submitted-message').textContent = example.text;
  document.querySelector('#result-label').textContent = example.label;
  document.querySelector('#case-title').textContent = example.title;
  document.querySelector('#result-summary').textContent = example.summary;
  document.querySelector('#action-title').textContent = example.actionTitle;
  document.querySelector('#action-copy').textContent = example.actionCopy;
  document.querySelector('#interpretation-note').hidden = !example.interpretation;
  document.querySelector('#result-card').classList.toggle('high', !example.interpretation);
  document.querySelector('#evidence-list').replaceChildren(...example.signals.map(text => {
    const item = document.createElement('li');
    item.textContent = text;
    return item;
  }));
  window.scrollTo({ top: 0, behavior: 'instant' });
  document.querySelector('#case-title').focus({ preventScroll: true });
}

message.addEventListener('input', updateInput);
document.querySelectorAll('[data-reset]').forEach(button => button.addEventListener('click', reset));
document.querySelectorAll('[data-example]').forEach(button => button.addEventListener('click', () => {
  message.value = examples[button.dataset.example].text;
  updateInput();
  message.focus();
}));
document.querySelector('#consult-form').addEventListener('submit', event => {
  event.preventDefault();
  const match = Object.keys(examples).find(key => examples[key].text === message.value.trim());
  if (match) showExample(match);
  else {
    feedback.textContent = 'Esta propuesta visual no analiza texto libre. Elige uno de los ejemplos y pulsa «Revisar mensaje» para recorrer el diseño.';
    feedback.hidden = false;
  }
});

const modalContent = {
  account: ['Guarda lo que te sirva. Vuelve cuando lo necesites.', 'La consulta inicial será abierta. Crear una cuenta añadirá continuidad y mayor uso, sin obligarte a guardar cada caso.'],
  history: ['Tus consultas, cuando quieras retomarlas.', 'Con una cuenta podrás guardar resúmenes por decisión propia, volver a ellos o eliminarlos. Esta pantalla muestra el beneficio; todavía no contiene un historial real.'],
  about: ['Señales, contexto y un siguiente paso.', 'La experiencia propuesta reúne comprobaciones verificables y una interpretación acotada del mensaje. Las fuentes y sus límites deben acompañar el resultado. Esta vista previa sólo utiliza ejemplos sintéticos.'],
  limits: ['Una ayuda para decidir. La certeza no se promete.', 'Un mensaje puede ser fraudulento aunque no se detecten señales. Una comprobación pendiente o fallida debe mostrarse como tal. En esta propuesta los resultados son ejemplos, sin consultas reales a fuentes o modelos.']
};
document.querySelectorAll('[data-modal]').forEach(button => button.addEventListener('click', () => {
  const key = button.dataset.modal;
  const [title, copy] = modalContent[key];
  document.querySelector('#dialog-title').textContent = title;
  document.querySelector('#dialog-copy').textContent = copy;
  document.querySelector('#account-benefits').hidden = !['account', 'history'].includes(key);
  dialog.showModal();
}));

document.querySelectorAll('[data-interaction]').forEach(button => button.addEventListener('click', () => {
  const key = button.dataset.interaction;
  if (selectedInteractions.has(key)) selectedInteractions.delete(key);
  else {
    if (key === 'none') selectedInteractions.clear();
    else selectedInteractions.delete('none');
    selectedInteractions.add(key);
  }
  document.querySelectorAll('[data-interaction]').forEach(item => item.setAttribute('aria-pressed', String(selectedInteractions.has(item.dataset.interaction))));
  const responses = [];
  if (selectedInteractions.has('none')) responses.push('Puedes detenerte y verificar por un canal que ya conozcas antes de responder.');
  if (selectedInteractions.has('clicked')) responses.push('No ingreses información ni descargues archivos desde el enlace. Abrirlo por sí solo no confirma que una cuenta esté comprometida.');
  if (selectedInteractions.has('shared')) responses.push('Si compartiste claves o códigos, contacta a tu entidad desde su app o un canal que ya conozcas para proteger la cuenta. No escribas esos datos aquí.');
  if (selectedInteractions.has('paid')) responses.push('Si hiciste un pago, contacta cuanto antes a tu entidad para consultar qué medidas están disponibles. No se puede garantizar recuperar el dinero.');
  document.querySelector('#follow-up-copy').textContent = responses.join(' ');
  document.querySelector('#follow-up').hidden = !responses.length;
}));

updateInput();
