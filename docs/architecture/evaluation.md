# Evaluación de señales e interpretación

Estado al 18-oct-2026: corpus de 24 fixtures sintéticos y ejecutor ExUnit incluidos en CI, con informe versionado. Se evalúan reglas offline; calidad del modelo, precisión en usuarios reales, latencia externa y costos siguen pendientes.

## Conjunto y etiquetas

Próxima ampliación propuesta: pasar de los 24 fixtures actuales a un conjunto de 50 a 100 casos. Incluir mensajes legítimos, fraude sustentado y casos insuficientes para concluir; bancos y billeteras, texto sin enlaces, dominios similares, números, lenguaje local, negaciones y mensajes con instrucciones dirigidas al modelo. Un conjunto pequeño orienta decisiones, sin representar la prevalencia nacional.

Cubrir los patrones del [catálogo de interpretación](ai-interpretation.md#salida-efectiva-y-política) en la medida del alcance aprobado, con contrapartes legítimas y ambiguas. Para sospechas sólo de texto, comprobar que el modelo puede advertir hasta `suspicious`, identifica la interpretación como tal y no inventa señales para alcanzar `high_risk`. Una política de marca se prueba con pedidos reales de datos y con negaciones, citas o consejos educativos que no deben dispararla.

Usar preferentemente ejemplos sintéticos inspirados en patrones documentados y referencias a alertas oficiales. Publicar sólo material con permiso y derechos revisados. Mensajes donados requieren consentimiento y anonimización antes de incorporarlos; no se necesita recolectarlos para completar el primer corte. No subir originales ni secretos a CI o a otro proveedor.

Cada caso tendrá `id`, origen y permiso, familia de patrón, texto sintético o saneado, etiquetas de referencia, evidencia necesaria, acciones esperadas y comprobaciones que pueden quedar indeterminadas. La etiqueta describe lo que permite concluir esa evidencia, sin convertir una sospecha en fraude probado. La expectativa no se obtiene del mismo modelo evaluado.

Separar casos usados para ajustar reglas o instrucciones de un conjunto final reservado. Agrupar variantes de la misma plantilla o campaña para que no queden casi duplicadas a ambos lados. Fijar corpus y snapshots antes de comparar modelos; registrar cantidad de casos por clase y desacuerdos de etiquetado. Mientras JP trabaje solo, declarar la falta de un segundo etiquetador independiente.

## Ejecutor actual y ampliación pendiente

El evaluador es una herramienta fuera del tráfico del usuario, ejecutada localmente o en CI sobre un entorno de prueba. Nunca genera tracción de usuarios ni accede a historiales de producción.

1. Cargar fixtures versionados y snapshots fijos; ejecutar reglas sin red para resultados reproducibles.
2. Comprobar extracción, procedencia, veredicto, cobertura y acciones esperadas. Las regresiones de reglas se mantienen en Phoenix; el motor TypeScript del prototipo se retiró.
3. Ejecutar pruebas del adaptador con respuestas simuladas: JSON inválido, señales inventadas, timeout, petición de secretos e intento de rebajar el piso de riesgo.
4. Comparar modelos reales en una corrida explícita con presupuesto, corpus permitido y proveedor habilitado. No hacer llamadas pagadas en cada PR ni desde contribuciones no confiables.
5. Generar un informe por commit, corpus, snapshot, política, instrucciones y modelo, sin mensajes de producción ni credenciales.

Las pruebas de CI de reglas y contrato son requisitos antes de integrar cambios. Las comprobaciones de fuentes vivas son pruebas separadas: su resultado puede cambiar y no sustituye la evaluación reproducible.

## Métricas

| Métrica | Definición y lectura |
|---|---|
| Matriz de confusión | Etiqueta de referencia frente a los cuatro veredictos; mostrar conteos y denominadores |
| Omisión de alerta alta | Casos etiquetados como alto riesgo que no reciben alto riesgo; separar sospechoso e indeterminado de una conclusión de ausencia de señales |
| Error peligroso | Alto riesgo de referencia que termina en `no_signals_detected`; prioridad de investigación |
| Falsos positivos | Mensajes legítimos con advertencias de riesgo injustificadas; revisar causa y clase |
| Elevación sólo por IA | Cambios a sospechoso sin señales deterministas y sus falsos positivos; ninguna elevación sin sustento a alto riesgo |
| Abstención y cobertura | Proporción indeterminada y fallos de comprobaciones, por tipo de caso |
| Afirmaciones sin soporte | Señales citadas inexistentes, verificaciones inventadas y canales ajenos al catálogo |
| Tiempo | Primera ayuda y evaluación final, por modo; p50 y p95 con tamaño de muestra y condiciones |
| Costo | Consumo real y costo por caso completado, incluidos fallos y reintentos |
| Comprensión | Persona explica el resultado y el siguiente paso; prueba de uso separada de la clasificación |

Registrar las repeticiones y variación de respuestas del modelo. Con pocas observaciones, los percentiles y las tasas son exploratorios; no redondearlos como una garantía de precisión. No sumar una tasa de acierto única que esconda errores peligrosos o abstenciones.

## Criterios antes de habilitar una versión

Propuesta de requisitos: conservar paridad del motor de señales, impedir rebajas de evidencia alta, rechazar referencias ajenas, mantener respuesta útil si falla IA y no filtrar los secretos sintéticos de las pruebas a salidas, logs o persistencia. Fallar uno de estos casos detiene esa versión hasta corregir o documentar una limitación que JP deba validar.

La evaluación mínima de esos invariantes acompaña al primer corte P0. El informe ampliado de 50 a 100 casos y la comparación de varios modelos pueden tener una prioridad posterior; aplazar ese informe no aplaza las comprobaciones necesarias para habilitar la IA. El conjunto mínimo debe incluir fraude sustentado, texto sospechoso sin enlaces, un mensaje legítimo parecido, fuente caída, salida inválida e inyección de instrucciones.

Los umbrales de calidad, latencia y costo se fijan después de la primera medición, antes de elegir modelo y publicar afirmaciones. Presentar el informe completo y sus límites; el número de pruebas aprobadas no equivale al número de usuarios ni a fraudes evitados.


## Resultado reproducible del 18-oct

Se ejecutaron 24 fixtures sintéticos en CI, con reglas activas y red desactivada, sin usar el modelo ni el feed. Hubo 0 resultados verdes en los casos etiquetados riesgosos, 0 falsas alarmas en los legítimos y 6 abstenciones. Las abstenciones se conservan como categoría propia, no como aciertos. Son ejemplos de regresión escritos por el equipo, no un conjunto reservado ni una estimación de precisión en mensajes reales. Tampoco miden calidad del LLM, latencia externa o eficacia de prevención.

Corpus: `api/test/fixtures/evaluation.json`; ejecutor: `api/test/evaluation_test.exs`, incluido en `mix test`. [Resultado completo](evaluation-report.json). [Ejecución CI](https://github.com/deep-skill/everyday-trust/actions/runs/39102714048). El ejecutor es parte de la suite Phoenix; no llama al modelo ni modifica código de producción.
