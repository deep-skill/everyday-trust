import type { CaseResult } from './cases';

const explanations: Record<string, [string, string]> = {
  google_safe_browsing: ['Google detectó una amenaza en el enlace', 'Google Safe Browsing marca esta dirección como posiblemente engañosa o peligrosa. No la abras; verifica por un canal oficial.'],
  urlscan_malicious: ['El escaneo encontró señales de riesgo', 'La navegación aislada de urlscan encontró indicios maliciosos. El resultado es una instantánea, no confirma la identidad del remitente.'],
  community_reported: ['La comunidad reportó este dominio', 'Varias sesiones lo compartieron y existe una señal independiente. Sigue siendo un candidato por revisar, no una confirmación de fraude.'],
  asks_credentials: ['Pide claves o códigos', 'Compartirlos puede permitir que otra persona entre a tu cuenta. Confirma la solicitud por un canal que ya conozcas.'],
  urgency: ['Te presiona para actuar rápido', 'Las amenazas de bloqueo o los plazos urgentes pueden hacer que respondas sin verificar.'],
  family_impersonation: ['Dice ser un familiar con otro número', 'Comprueba quién escribe llamando al número que ya tenías guardado.'],
  asks_money: ['Te pide enviar dinero', 'Confirma a quién pagarías y por qué, usando un contacto que ya conozcas.'],
  extortion: ['Incluye amenazas o presión para pagar', 'Conserva las pruebas y busca ayuda por un canal oficial.'],
  prize_or_refund: ['Ofrece un premio, bono o devolución', 'Verifica la oferta por tu cuenta antes de pagar o compartir datos.'],
  easy_job: ['Promete dinero por tareas sencillas', 'Comprueba quién ofrece el trabajo, especialmente si después te pide un pago.'],
  package_held: ['Usa un problema con un envío como motivo', 'Revisa el estado del pedido desde la empresa con la que compraste.'],
  brand_lookalike: ['El enlace no coincide con la marca', 'La dirección se parece o menciona a una marca, pero no pertenece a sus sitios oficiales confirmados.'],
  url_userinfo: ['La dirección puede ocultar su destino', 'El texto antes de una arroba en un enlace puede hacer que parezca de otra empresa.'],
  punycode: ['El enlace usa letras que pueden confundirse', 'Algunos caracteres se parecen a otros y pueden imitar el nombre de un sitio conocido.'],
  suspicious_tld: ['La dirección merece otra comprobación', 'La terminación del enlace es una señal adicional; por sí sola no demuestra una estafa.'],
  new_domain: ['El sitio se creó hace poco', 'Su dirección tiene menos de un mes. Comprueba su relación con la empresa antes de usarlo.'],
  recent_domain: ['La dirección tiene pocos meses', 'Es una señal adicional para revisar, no una prueba de fraude.'],
  shortener: ['El enlace oculta su dirección completa', 'Un enlace corto puede llevarte a otro sitio. Revisamos su destino cuando es posible.'],
  unresolved_shortener: ['No pudimos confirmar el destino', 'La dirección corta no permitió completar la comprobación. No sabemos a qué sitio te llevaría.'],
  no_https: ['El enlace no protege la conexión', 'La dirección no usa una conexión cifrada. Evita ingresar información personal.'],
  ip_address: ['La dirección no muestra el nombre de una empresa', 'Usa números en lugar de un nombre de sitio. Confirma su origen antes de continuar.'],
  invalid_url: ['No pudimos reconocer bien el enlace', 'Comprueba que esté copiado completo. No podemos confirmar su destino con esta dirección.'],
  foreign_number: ['Incluye un número extranjero', 'Comprueba si tiene sentido en esta conversación. Esto no identifica a su titular ni demuestra fraude.'],
  incomplete_link_checks: ['Hay enlaces que no pudimos comprobar', 'El mensaje incluye más enlaces de los que revisamos en una sola consulta.'],
  reported_phishing: ['El sitio aparece en alertas de engaños', 'Encontramos un reporte sobre esa dirección. El reporte puede ser antiguo y no confirma su estado actual.'],
  source_conflict: ['La información disponible no coincide', 'Encontramos datos contradictorios sobre la dirección. Verifica por otro canal.'],
  destination_changed: ['El sitio lleva a otra dirección', 'Al comprobar el sitio, encontramos una redirección a otra dirección. Verifica que pertenezca a la empresa esperada.']
};

export function explainSignals(result: CaseResult) {
  const unique = [...new Map(result.signals.map(signal => [signal.id, signal])).values()];
  return unique.map(signal => {
    const [title, detail] = explanations[signal.id] ?? ['Una señal que conviene revisar', signal.message];
    return { id: signal.id, title, detail };
  });
}
