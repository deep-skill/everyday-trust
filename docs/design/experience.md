# Experiencia y pantallas de la primera versión

Estado: borrador para validar antes de implementar UI. Deriva del [alcance de negocio](../business/product.md).

La web abre en una superficie de consulta. El centro de la experiencia es el caso: entrada, resultado visible y seguimiento contextual. La cuenta aparece como beneficio de continuidad y mayor uso.

## Navegación

- **Nueva consulta:** texto o enlace, ejemplos sintéticos y explicación breve del servicio.
- **Caso:** evaluación, evidencias, qué hacer y conversación de seguimiento.
- **Mi historial:** resúmenes guardados, fecha, riesgo y opciones para retomar o borrar.
- **Mi cuenta:** sesión, cuota disponible y eliminación de cuenta.
- **Cómo funciona y privacidad:** cobertura de las comprobaciones y tratamiento de datos.

## Flujos principales

1. Visitante pega un mensaje, recibe una advertencia para omitir datos personales y puede corregirlo. Tras enviarlo ve las señales iniciales; la UI indica qué sigue pendiente y actualiza la evaluación sin exigir cuenta.
2. Visitante elige «Guardar este caso». Se explican los datos que se conservan y se ofrece crear cuenta o entrar. Tras autenticarse vuelve al caso pendiente, conservado temporalmente, y confirma el guardado.
3. Persona con cuenta abre historial, retoma un resumen o elimina un caso. La UI confirma la eliminación y actualiza la lista.
4. Si se agota la cuota anónima, se explica cuándo se renueva y el beneficio gratuito de cuenta. La evaluación ya entregada sigue accesible durante la sesión.
5. Si falla el modelo o una fuente externa, el resultado conserva las señales disponibles e indica qué parte no pudo completarse.
6. Después del resultado puede indicar «No interactué», «Abrí el enlace», «Compartí datos» o «Pagué», incluso más de una. La orientación distingue prevención de respuesta y no solicita claves, códigos ni datos de la operación.
7. Puede responder «Me ayudó / No me ayudó» o iniciar otra consulta. El feedback es opcional y no condiciona el resultado ni requiere texto adicional.

## Pantallas antes del diseño visual

Los wireframes deben cubrir consulta vacía, análisis en curso, resultado con seguimiento, acceso a cuenta e historial. Se diseñan primero para 390 px y después para escritorio. En móvil, la navegación secundaria se colapsa; el resultado y las acciones conservan prioridad.

Primeros esquemas de contenido: [consulta](../diagrams/rendered/wireframe-consultation.svg), [revisión en curso](../diagrams/rendered/wireframe-analysis.svg), [historial](../diagrams/rendered/wireframe-history.svg) y [beneficio de registro](../diagrams/rendered/wireframe-signup.svg). Estos esquemas de baja fidelidad todavía no representan la adaptación final a 390 px ni la identidad visual.

No se depende de una animación o de una conversación larga para mostrar una señal de riesgo. El resultado usa una etiqueta textual junto al color. «No encontramos señales suficientes» es distinto de «No hay riesgo».

La tarjeta muestra etiqueta, una frase de motivo, la acción prioritaria y hasta tres señales principales. «Ver evidencias y fuentes» amplía el detalle sin esconder una advertencia crítica. La cobertura y las comprobaciones pendientes se ven junto al resultado; la actualización no desplaza el foco ni borra la conversación.

El titular usa el veredicto explícito, por ejemplo «Alto riesgo: posible suplantación», sólo cuando la evidencia lo sustenta. La acción prioritaria conduce al canal oficial curado de la entidad, si existe y está vigente. Si no está verificado, explica cómo abrir su app o buscar su sitio por un camino conocido; no sustituye ese dato con un teléfono generado por IA.

## Estados y recuperación

| Superficie | Estados obligatorios | Respuesta del usuario |
|---|---|---|
| Entrada | Vacía, válida, demasiado larga, enviando, cuota agotada | Corregir, reintentar o entrar |
| Veredicto | Alto riesgo, sospechoso, sin señales detectadas, indeterminado | Entender señales y elegir acción |
| Procesamiento y cobertura | En curso o finalizado; comprobaciones pendientes, disponibles o no disponibles | Ver lo que falta y las limitaciones; cobertura parcial no es un quinto veredicto |
| Seguimiento | Disponible, respondiendo, fuera de alcance, fallo, sesión temporal vencida | Reintentar o crear otra consulta |
| Cuenta | Acceso, registro, confirmación, recuperación, error, cancelación | Volver al caso sin perder el contexto permitido |
| Historial | Vacío, con resultados, cargando, fallo, borrado | Abrir resumen o volver a consultar |

## Contenido y tono

Escribir en español claro, con «mensaje», «enlace» y «cuenta». Explicar el motivo antes de pedir datos o permisos. Nunca solicitar contraseñas bancarias ni códigos de operación en la consulta.

La advertencia de privacidad está junto a la entrada y al guardado. Debe explicar qué se procesa, si interviene un proveedor de IA, cuánto dura el contexto temporal y qué se conserva al guardar. Las duraciones definitivas y condiciones del proveedor deben estar validadas antes de publicar ese texto. No se promete una detección perfecta de datos personales.

Ejemplo de resultado: «Encontramos señales de suplantación. El dominio menciona a BCP, pero no coincide con sus dominios oficiales verificados». La evidencia debe corresponder a una comprobación real. Las instrucciones de ayuda se mantienen en un catálogo con fuentes verificadas.

La UI distingue «fuente consultada», «última actualización» y «comprobación no disponible». No presenta un puntaje de reglas como porcentaje de certeza.

Si el riesgo sube sólo por interpretación del texto, la tarjeta dice «Sospechoso» y muestra «Interpretación de IA, sin corroboración externa del patrón». La explicación puede señalar el pedido urgente de dinero, pero no inventar una lista de phishing consultada. La evidencia por reglas y la interpretación mantienen etiquetas distintas al guardar o retomar.

Mientras hay comprobaciones pendientes, se muestra «Revisión en curso» y las advertencias confirmadas; no se anuncia «sin señales detectadas» como conclusión final. Al guardar se conserva una instantánea finalizada con su cobertura, que puede ser parcial si hubo fallos.

## Propuesta visual para revisar

La [identidad 0.1](brand.md) aplica el nombre y la bajada elegidos por JP a una [consulta interactiva de ejemplo](proposal/index.html), con capturas de móvil y escritorio. Es una revisión separada de la app, sin análisis real, autenticación ni persistencia. Ilustra jerarquía, evidencia ampliable, orientación y beneficio de cuenta; todavía faltan los estados de carga, fallo, cuotas y recorridos completos de auth/historial.

## Accesibilidad y revisión

Objetivo: WCAG 2.2 AA en las pantallas principales. Navegación por teclado, foco visible, etiquetas de formulario, mensajes de error asociados, cambios de estado anunciados y contraste suficiente. El color no es el único medio para expresar riesgo.

Pruebas de uso: completar una consulta sin ayuda; explicar qué se comprobó y qué falta; encontrar la acción según si ya hubo clic, datos compartidos o pago; crear cuenta para guardar; recuperar y borrar un caso. La validación visual revisa 390 px y escritorio, carga, error y contenido largo.

Referencia: [WCAG 2.2](https://www.w3.org/TR/WCAG22/).
