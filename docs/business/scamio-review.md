# Qué cambia tras revisar Scamio

Estado: revisión documental del 17 de octubre de 2026. Se contrastaron páginas oficiales y la política de privacidad. No se inició sesión ni se ejecutó una evaluación comparativa del producto.

## Evidencia y límites

| Hallazgo | Sustento | Implicación para el proyecto |
|---|---|---|
| Scamio ofrece revisión conversacional gratuita y exige una cuenta antes de usarlo | [Producto](https://www.bitdefender.com/en-us/consumer/scamio) y [soporte](https://www.bitdefender.com/consumer/support/answer/97320/) | El chat verificador ya existe. Nuestra consulta inicial abierta reduce un paso; su efecto en uso debe medirse |
| Acepta mensajes, enlaces, imágenes, QR y descripciones | [Soporte](https://www.bitdefender.com/consumer/support/answer/97320/) | No competir por cantidad de formatos en la primera entrega. Texto y enlaces siguen siendo el alcance propuesto |
| La documentación de soporte consultada indica respuestas en inglés | [Soporte](https://www.bitdefender.com/consumer/support/answer/97320/) | Falta probar la experiencia actual en español. No presentar su ausencia como un diferencial demostrado |
| Su política distingue el procesamiento automático de otros tratamientos y fija para el primero un máximo de dos meses | [Política, sección 7.8](https://www.bitdefender.com/en-us/site/view/legal-privacy-policy-for-home-users-solutions) | Explicar nuestra propia conservación por tipo de dato; no copiar el plazo ni prometer condiciones del proveedor sin verificarlas |
| La misma política declara Azure OpenAI y excluye datos personales del entrenamiento; contempla información anonimizada para mejora | [Política, sección 7.8](https://www.bitdefender.com/en-us/site/view/legal-privacy-policy-for-home-users-solutions) | Minimizar antes de enviar al modelo y revisar contrato, configuración y conservación del proveedor que elijamos |
| Scam Protection Pro incluye capacidades preventivas y borrado del historial de chat | [Soporte de Scam Protection Pro](https://www.bitdefender.com/consumer/support/answer/103356/) | Es un referente para la evolución hacia protección continua; no atribuir todas las funciones de Pro al Scamio gratuito |

El análisis local del código público reporta cuatro categorías de resultado, señales desplegables y botones de feedback. Son indicios de interfaz, no una prueba de su funcionamiento tras autenticarse. Los límites de archivos y de uso no se convierten en requisitos nuestros.

Un 404 en una página regional no demuestra falta de cobertura en Perú. Tampoco se verificó que Scamio rechace consultas sobre teléfonos o carezca de pasos locales. La ventaja peruana sigue siendo una hipótesis que requiere comparar los mismos casos con una referencia etiquetada. No hay evidencia aquí para afirmar mayor precisión o menor latencia.

## Ajustes propuestos

| Decisión documental | Motivo | Alcance |
|---|---|---|
| Cuatro veredictos y cobertura por separado | La incertidumbre debe poder expresarse sin forzar una respuesta binaria | B02, UX y contrato |
| Resultado breve, acción visible y evidencia ampliable | La persona necesita decidir antes de leer una explicación larga | B02 y wireframe |
| Señales iniciales antes de esperar fuentes lentas o IA | La explicación adicional no debe retener una advertencia disponible | VSM, secuencia y propuesta de contrato por etapas |
| Pregunta opcional sobre clic, datos compartidos o pago | La orientación cambia si la persona ya interactuó | B03 y seguimiento |
| Minimización antes del modelo y del estado temporal | Evitar enviar o conservar secretos que no hacen falta para interpretar | B07, C4 y modelo de datos |
| Feedback breve y opcional | Medir utilidad percibida sin recopilar otra copia del mensaje | B08; no equivale a una etiqueta de fraude verdadera |

Se mantienen la consulta sin registro y la cuenta gratuita con historial voluntario y mayor cuota. La monetización sigue como hipótesis de protección continua. No se condiciona la ayuda a una compra ni se usa un resultado alarmante para presionar una suscripción.

Capturas, PDF, QR, reporte comunitario y compartir resultados siguen fuera del primer corte. Si se incorporan reportes, no alimentarán automáticamente listas de bloqueo. Compartir requeriría una vista saneada, sin el mensaje original ni enlaces peligrosos activos.

## Validación pendiente

Probar comprensión del resultado y siguiente acción con casos sintéticos legítimos, fraudulentos e inconclusos. Medir por separado la primera señal útil y la evaluación final; comprobar degradación cuando una fuente o el modelo no responde. Comparar contexto peruano y acciones recomendadas sin convertir una demostración pequeña en una tasa general de precisión.

Estos ajustes no eligen lenguaje, autenticación ni servicios de AWS. Continúa el orden acordado: revisar negocio y experiencia, cerrar diseño técnico y validar antes de programar.
