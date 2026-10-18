# Contrato funcional de la API

Estado: contrato funcional objetivo. El primer corte ya implementa estos recursos en Phoenix, con respuesta finalizada síncrona y guardado idempotente por cuenta/caso. Las propuestas de continuación asíncrona siguen sin implementar. Ver [estado físico y límites](implementation.md).

La API usa el prefijo `/api/v1`, JSON y una política explícita de acceso por recurso. Los identificadores no conceden acceso. Una operación sobre un caso temporal exige su sesión original; una operación sobre un caso guardado exige su propietario autenticado.

| Operación | Acceso | Resultado esperado |
|---|---|---|
| `POST /cases` | Visitante o cuenta, con cuota | Crea caso temporal y devuelve evaluación inicial, evidencias, comprobaciones pendientes y vencimiento |
| `GET /cases/{id}` | Sesión temporal correspondiente o propietario | Recupera la evaluación permitida, su revisión y el estado de procesamiento |
| `POST /cases/{id}/messages` | Mismo acceso del caso, con cuota de seguimiento | Responde una aclaración sin rebajar evidencia de alto riesgo |
| `POST /cases/{id}/save` | Cuenta y acceso válido al caso temporal | Guarda una instantánea finalizada con su cobertura, con idempotencia |
| `POST /cases/{id}/feedback` | Mismo acceso del caso, con límite por caso | Registra utilidad percibida sin texto libre, con idempotencia |
| `GET /history` | Cuenta | Lista sólo sus casos, con cursor de paginación |
| `GET /history/{id}` | Propietario | Recupera el resumen y evidencias históricas, con fecha de análisis |
| `DELETE /history/{id}` | Propietario | Elimina caso y evidencias |
| `GET /me` | Cuenta | Devuelve perfil mínimo, beneficios y cuotas |
| `DELETE /me` | Cuenta con autenticación reciente | Inicia eliminación coordinada de identidad y datos de aplicación |
| `GET /health` | Público, sin detalles internos | Salud del servicio y versión pública del despliegue |

Los endpoints de acceso, retorno de autenticación, salida y recuperación se concretarán con el proveedor de identidad y la estrategia de sesión acordados.

El contrato de salida de IA y sus límites se detallan en [interpretación](ai-interpretation.md). Las entidades y acciones permitidas se alimentan mediante [catálogos e ingesta](source-ingestion.md); estos documentos no habilitan consultas externas arbitrarias ni endpoints de administración públicos.

## Entrada y evaluación

El mensaje tiene un máximo inicial de 5.000 caracteres, heredado del prototipo; el límite también se aplica en servidor y al cuerpo HTTP antes de procesarlo. El seguimiento tendrá un máximo propio y un presupuesto de turnos por caso. Las cuotas anónimas y de cuenta siguen pendientes de aprobación.

Una evaluación contiene categoría de riesgo, resumen, señales, origen y fecha de las comprobaciones, cobertura, recomendaciones y versión de política. Una coincidencia con dominio oficial se refiere al dominio, no al origen autenticado del mensaje. Los destinos sospechosos no se convierten en enlaces de acción que inviten a visitarlos.

Incluye `baseline_verdict` y `risk_origin`, calculados por el servidor. Una interpretación sin señales deterministas puede elevar a `suspicious`, identificada como tal; para `high_risk` debe existir sustento adicional según la política. No se inventan señales o una fuente para justificar esa elevación. `scam_type` es una hipótesis del catálogo cerrado de patrones.

Los cuatro veredictos propuestos son `high_risk`, `suspicious`, `no_signals_detected` e `inconclusive`. No hay una categoría que garantice seguridad. La cobertura parcial no constituye un quinto veredicto.

Los estados de comprobación distinguen `pending`, `match`, `no_match`, `unavailable` y `not_applicable`. El resultado incluye `analysis_mode` para diferenciar análisis por señales de uno complementado por IA. La falta de una dependencia no produce una señal de legitimidad.

## Entrega por etapas y seguimiento

Propuesta para validar: `POST /cases` entrega la evidencia local sin esperar al modelo y devuelve 201 al crear el recurso. `analysis_status` distingue `in_progress` de `completed`; la cobertura describe por separado los fallos. Se incluye una revisión creciente de evaluación para evitar que una respuesta antigua reemplace una nueva en la UI.

Mientras está en curso, el veredicto puede advertir un riesgo sustentado o ser `inconclusive`; `no_signals_detected` se reserva para una revisión finalizada, con sus limitaciones visibles. Al vencer el plazo, las comprobaciones pendientes pasan a `unavailable` y el caso termina con la cobertura disponible. El piso de riesgo verificable se conserva en cada revisión.

Finalizado no significa concluyente: cuando la cobertura o la evidencia no bastan para evaluar el caso, se mantiene `inconclusive`. Ningún timeout habilita por sí solo `no_signals_detected`.

`GET /cases/{id}` permite recuperar actualizaciones sin volver a cobrar cuota de análisis. Su frecuencia también se limita. Sondeo o streaming y la ejecución confiable de la continuación se definirán con el stack, antes del OpenAPI. Un intento de guardar mientras el análisis sigue en curso recibe 409 y conserva acceso al resultado ya visible.

El seguimiento admite categorías opcionales de interacción: `clicked`, `shared_data` y `paid`, combinables, o ninguna. No pide el valor de códigos, credenciales ni datos del pago. Toda entrada se minimiza antes de conservarse o enviarse al modelo. El feedback acepta sólo `helpful` o `unhelpful`; no se usa para incorporar teléfonos o dominios a listas de fraude.

## Respuestas y errores

| Código | Uso |
|---|---|
| 200 o 201 | Lectura, operación completada o recurso creado; el análisis puede seguir `in_progress` |
| 202 | Eliminación de cuenta iniciada cuando requiere coordinación asíncrona |
| 400 o 413 | Entrada inválida o tamaño excedido |
| 401 | Falta una identidad requerida |
| 403 | Solicitud bloqueada por origen, protección CSRF o permisos insuficientes |
| 404 | Recurso inexistente, ajeno o caso temporal vencido |
| 409 | Conflicto de estado o clave de idempotencia usada con otra entrada |
| 429 | Cuota o presupuesto de operación excedido, con `Retry-After` |
| 503 | Capacidad o dependencia obligatoria no disponible; error acotado y reintentable |

Los errores contienen código estable, mensaje para el usuario e identificador de petición. No incluyen diagnóstico del proveedor, secretos o contenido recibido. Un timeout del modelo puede producir una evaluación por señales válida con cobertura parcial; no se confunde con un error de toda la operación.

## Condiciones antes de implementar

El OpenAPI versionará schemas, ejemplos sintéticos, autenticación, paginación, límites e idempotencia. El prototipo tiene `POST /api/analyze`; se conservará o retirará mediante una migración explícita tras validar el nuevo contrato. La especificación debe decidir qué estado del caso vive en el cliente y qué estado temporal necesita el servidor.
