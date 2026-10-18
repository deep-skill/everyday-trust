# Contrato del intérprete de IA

Estado al17-oct-2026: JP confirmó `muse-spark-1.3-contributor` y pidió enviar el mensaje completo y todas las comprobaciones durante las pruebas internas de hackathon. Esta decisión reemplaza la restricción anterior a códigos de señales. Antes de abrir al público general se cambiará el modelo/modalidad. AWS conserva IA desactivada hasta publicar el corte; la llave permanece fuera de Git y cifrada en runtime.

El modelo interpreta el lenguaje y los hechos disponibles. La aplicación conserva la decisión final, las explicaciones revisadas y los siguientes pasos. Una salida válida no prueba fraude ni demuestra vulnerabilidades.

## Entrada efectiva del piloto

El adaptador envía exactamente dos campos en la interpretación inicial:

| Campo | Contenido |
|---|---|
| `message` | Texto original completo, incluidos enlaces, rutas, parámetros y números que contenga; sin minimización ni recorte |
| `analysis` | Resultado íntegro del motor: señales con sus mensajes/fuentes, dominios revisados, cobertura, veredicto base, puntaje, consejos y metadatos del análisis |

El servidor no agrega cookies, tokens de sesión, credenciales del proveedor ni datos de identidad de la cuenta. El texto original sólo se captura en la tarea asíncrona; no entra al resultado guardado, al contexto PostgreSQL ni a logs. Esto no impide que el proveedor lo procese según sus condiciones.

El prompt distingue el mensaje y las fuentes como datos no confiables. Las URLs y el texto no se convierten en instrucciones. Contributor no recibe herramientas de navegación o escritura. DNS, HTTP, registro y alertas son comprobaciones de módulos locales, descritas en [implementación](implementation.md#comprobación-de-sitios-y-contributor-corte-local).

## Salida efectiva y política

El adaptador solicita JSON y consume tres campos:

| Campo | Restricción |
|---|---|
| `suggested_verdict` | `high_risk`, `suspicious`, `no_signals_detected` o `inconclusive` |
| `scam_type` | Valor del catálogo cerrado; uno desconocido se convierte en `undetermined` |
| `cited_signal_ids` | Lista de hasta ocho ids presentes en el caso; puede estar vacía para una interpretación sólo del texto |

No se muestra prosa del proveedor. Títulos, explicaciones, consejos y contactos proceden de contenido revisado en la aplicación. Referencias inventadas, JSON inválido o salida mayor de8.000 bytes causan fallback.

El modelo nunca reduce el piso determinista. Una interpretación sin corroboración puede elevar como máximo a `suspicious`, incluso si el proveedor propone alto riesgo. Se marca como interpretación. Una respuesta HTTP o coincidencia con sitio oficial no autentica al remitente ni acredita seguridad. El prompt prohíbe afirmar vulnerabilidades, malware o una verificación externa que no se realizó.

Catálogo: `bank_impersonation`, `wallet_impersonation`, `credential_theft`, `advance_payment`, `account_takeover`, `family_emergency`, `mistaken_transfer`, `fake_loan`, `job_task_scam`, `prize_or_raffle`, `extortion`, `other`, `undetermined`. Son hipótesis de modalidad, no delitos probados.

## Seguimiento

Las categorías de clic, datos compartidos y pago seleccionan orientación local. Para otras preguntas, el modelo recibe `question` completo y `case` con todo el resultado disponible y selecciona una intención cerrada: `explain_signals`, `verify_identity`, `limits` u `out_of_scope`. La respuesta al usuario continúa siendo texto revisado en servidor.

La petición inicial es independiente del seguimiento. Como no se conserva el mensaje original, una pregunta posterior dispone del resultado estructurado, pero no recupera aquel texto ni una conversación completa. No se anuncia memoria semántica de todos los turnos.

El adaptador alternativo `deepseek-flash` mantiene minimización y sigue sin seleccionarse para el piloto. No se afirma compatibilidad de condiciones ni rendimiento entre proveedores.

## Plazos y presupuesto implementados

| Recurso | Límite actual |
|---|---|
| Instrucciones y entrada Contributor |65.536 bytes UTF-8 en conjunto; acepta los5.000 caracteres Unicode del formulario sin recortar |
| Entrada del adaptador alternativo |3.000 bytes UTF-8 en conjunto |
| Salida solicitada |600 tokens |
| Conexión / respuesta |1s /6s, sin reintentos facturables |
| Interpretaciones concurrentes |20 tareas supervisadas |
| Finalización de caso pendiente |8s; señales iniciales disponibles antes |
| Presupuesto global |200 llamadas de IA por día UTC |

Meta usa `reasoning_effort=minimal`. En el corte previo, una llamada del preview quedó no disponible y conservó señales; otra del adaptador respondió HTTP200 en4.402ms. Son observaciones de aquel modo y no garantizan la latencia del nuevo contexto completo.

Timeout, presupuesto agotado, rechazo, JSON inválido o caída del proveedor conservan las señales y declaran cobertura incompleta. No se repara con llamadas adicionales ni se concede un resultado verde por un fallo. Cuotas de consulta y seguimiento en [implementación](implementation.md).

## Decisión y configuración

JP indicó expresamente que las próximas pruebas son internas de hackathon y autorizó el contexto completo. La modalidad Contributor permite entrenamiento y sus condiciones restringen datos personales, sensibles o confidenciales. El piloto se evalúa con mensajes ficticios; la autorización de JP no cambia las condiciones del proveedor. Antes del lanzamiento general se sustituirá modelo/modalidad. Referencias: [condiciones Meta](https://dev.meta.ai/legal/terms-of-service) y [modelos](https://dev.meta.ai/docs/models).

El arranque de producción requiere `AI_PROVIDER=meta`, `AI_DATA_APPROVED=true`, `AI_INPUT_MODE=full_context` y `MODEL_API_KEY`. Se debe publicar primero la imagen compatible y actualizar sólo esos campos del runtime, sin regenerar secretos. La versión pública anterior bloquea Meta. Runbook canónico en `devops-agents`; no habilitado en AWS por este cambio local.

Muse Spark admite entrada multimodal, pero esta app sólo integra texto y enlaces. No se anuncia recepción de capturas, lectura de HTML o ejecución de JavaScript. Referencias: [audio y vídeo](https://dev.meta.ai/docs/video-understanding), [razonamiento](https://dev.meta.ai/docs/reasoning).

## Verificación

Las pruebas inspeccionan igualdad del mensaje y análisis completos, transmisión íntegra de5.000 caracteres Unicode, contexto de preguntas y captura asíncrona sin persistir el original. Se conservan pruebas de piso de reglas, citas inventadas y límite de sospecha por interpretación. Sólo se usan fixtures sintéticos en llamadas externas.

Falta evaluar falsos positivos, abstenciones, latencia y costo con un corpus etiquetado. Ver [evaluación](evaluation.md).

Integración del nuevo modo: el ejemplo bancario ficticio ejecutado desde Chrome terminó con analysis_status=completed, analysis_mode=signals_and_ai y coverage.ai=completed. Se conservó el alto riesgo de reglas.
