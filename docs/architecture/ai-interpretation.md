# Contrato del intérprete de IA

Estado: contrato para la API Elixir/Phoenix confirmada. JP indicó API directa y dos candidatos: `muse-spark-1.3-contributor` y `deepseek-flash`. La selección final, las condiciones de datos y los límites monetarios están pendientes; no hay llamadas habilitadas por este documento.

El modelo interpreta un caso y explica las señales disponibles. La política de riesgo de la aplicación decide el resultado final. Una respuesta bien formada no demuestra que sea correcta.

## Entrada permitida

| Campo | Contenido y límite |
|---|---|
| `schema_version`, `policy_version`, `prompt_version` | Versiones fijadas por el servidor |
| `task` | `initial_explanation` o `case_followup` |
| `case_context` | Texto minimizado; nunca el original como copia adicional |
| `signals` | ids, severidad, hechos calculados, procedencia y estado de las comprobaciones |
| `baseline_verdict`, `risk_floor` | Resultado de reglas y mínimo que debe conservar la política |
| `interaction` | Categorías opcionales de clic, datos compartidos o pago, sin los valores involucrados |
| `allowed_actions` | ids de acciones de un catálogo curado, filtradas para el caso |
| `followup` | Pregunta y contexto reciente minimizados; sólo en seguimiento |

El servidor prepara la entrada con campos permitidos y tamaño acotado. Una coincidencia con un dominio oficial no se convierte en autenticación del remitente. Si no puede preparar contexto permitido, omite la llamada y mantiene las señales.

## Salida propuesta

JSON estricto, sin campos adicionales. El adaptador devuelve un objeto validado o un fallo clasificado, nunca texto del proveedor tratado directamente como resultado.

| Campo | Restricción |
|---|---|
| `schema_version` | Versión esperada por el adaptador |
| `suggested_verdict` | `high_risk`, `suspicious`, `no_signals_detected` o `inconclusive` |
| `scam_type` | Un valor del catálogo cerrado de patrones descrito abajo |
| `explanation` | Español claro, máximo propuesto de 500 caracteres |
| `cited_signal_ids` | Hasta 8 ids presentes en la entrada; puede estar vacío cuando la sospecha procede sólo de interpretar el texto |
| `action_ids` | Hasta 3 ids de `allowed_actions` |
| `followup_answer` | Nulo en explicación inicial; máximo propuesto de 700 caracteres en seguimiento |
| `scope` | `in_scope` u `out_of_scope` |

Ejemplo sintético del objeto esperado, con un id de señal ilustrativo que debe existir en la entrada:

```json
{
  "schema_version": "1",
  "suggested_verdict": "suspicious",
  "scam_type": "bank_impersonation",
  "explanation": "El dominio menciona a la entidad y no coincide con los dominios oficiales comprobados.",
  "cited_signal_ids": ["brand_domain_mismatch"],
  "action_ids": ["verify_through_official_channel"],
  "followup_answer": null,
  "scope": "in_scope"
}
```

Los nombres y límites se cerrarán en el schema físico. No se solicita una probabilidad de certeza. La UI obtiene títulos, canales y enlaces de fuentes curadas, no de destinos inventados por el modelo.

## Catálogo de patrones

Los tipos describen hipótesis de modalidad, no delitos probados ni patrones exclusivos de Perú. Se elige el patrón principal para orientar el siguiente paso; mencionar Yape como medio de pago no basta para clasificar suplantación de la billetera.

| Valor | Patrón | Orientación que deberá tener una acción curada |
|---|---|---|
| `bank_impersonation` | Mensaje que aparenta ser de un banco | Verificar desde un canal oficial de la entidad |
| `wallet_impersonation` | Mensaje que aparenta ser de una billetera | Verificar en su app o canal oficial |
| `credential_theft` | Pedido de claves o códigos | Protección de credenciales según política oficial |
| `advance_payment` | Adelanto para obtener algo prometido | Verificación independiente antes de un pago |
| `account_takeover` | Intento de tomar control de una cuenta | Recuperación y protección por el canal correspondiente |
| `family_emergency` | Familiar con número nuevo y pedido urgente de dinero | Confirmar por un contacto previamente conocido |
| `mistaken_transfer` | Supuesta transferencia por error y pedido de devolución | Comprobar el movimiento en la propia app y usar el procedimiento oficial |
| `fake_loan` | Préstamo con cobro adelantado o condiciones dudosas | Verificar entidad y aviso regulatorio aplicable, si está integrado |
| `job_task_scam` | Tareas o trabajo que exigen depositar para cobrar | Verificar la oferta y reconocer el pedido de pago |
| `prize_or_raffle` | Premio o sorteo con cobro previo | Verificar organizador y condiciones por un canal independiente |
| `extortion` | Amenaza o exigencia coercitiva de dinero | Derivación a ayuda especializada con canales oficiales verificados |
| `other`, `undetermined` | Otro patrón o evidencia insuficiente | Declarar el límite de cobertura |

Ampliar el catálogo no amplía automáticamente el primer corte más allá del foco acordado en bancos y billeteras. Las acciones requieren fuentes curadas y disponibilidad real de la integración; no se inventan números de atención. Extorsión exige un protocolo específico antes de ofrecer orientación detallada.

## Validación y aplicación de política

1. Validar tamaño, JSON, esquema, catálogos y referencias. Rechazar ids ausentes, texto excesivo o campos inesperados.
2. Comprobar que el texto no agregue contactos, dominios o cifras sin soporte. Los contactos y enlaces de acción se renderizan desde `action_ids`; no desde texto libre del modelo.
3. Aplicar minimización también a la salida. Mostrarla como interpretación, diferenciada de los hechos comprobados. Rechazar contenido que pida secretos o afirme una verificación no realizada.
4. Aplicar el piso determinista. Una interpretación no borra una coincidencia verificable de alto riesgo ni convierte falta de cobertura en legitimidad.
5. Aplicar una política asimétrica: una interpretación válida del texto puede elevar hasta `suspicious`, aunque no haya señales deterministas ni enlaces. Esa advertencia se marca como interpretación, sin presentarla como comprobación externa. Elevar a `high_risk` requiere evidencia citada que lo sustente o un patrón validado por la política; el valor de `scam_type` por sí solo no cumple ese requisito. Nunca bajar del piso de reglas.

Una coincidencia en listas y una interpretación de lenguaje son clases de evidencia distintas. El modelo no crea `SourceVersion`, modifica catálogos ni produce una etiqueta de entrenamiento verdadera. Los filtros de salida y el delimitado reducen riesgo; no se presentan como defensa perfecta contra inyección.

La API calcula `risk_origin` (`rules`, `model_interpretation` o `combined`) y conserva `baseline_verdict`, sin confiar esa atribución al modelo. Una salida que propone alto riesgo basándose sólo en texto queda limitada a sospechoso. Una lista vacía de ids es válida para esa interpretación; una lista que contiene ids inventados se rechaza.

Caso de aceptación sintético: un mensaje de supuesto familiar con número nuevo y pedido urgente de dinero puede recibir `suspicious` por interpretación y una acción de confirmación, sin fabricar una coincidencia de phishing. Incluir también solicitudes legítimas parecidas para medir falsos positivos. Una interpretación de bajo riesgo nunca habilita una categoría de seguridad ni suprime una advertencia determinista.

Si devuelve `out_of_scope`, la aplicación conserva la evaluación existente y usa una respuesta acotada para volver al caso. No aplica un cambio de veredicto por una pregunta ajena.

## Aislamiento y fallos

La plantilla de instrucciones es del servidor. El mensaje, las respuestas anteriores y el contenido de fuentes se incorporan como datos no confiables, separados de las instrucciones. El modelo no recibe herramientas para navegar, escribir bases, ejecutar pagos ni cambiar permisos. Una pregunta fuera del caso devuelve `out_of_scope` y propone otra consulta.

Timeout, rechazo del proveedor, JSON inválido, referencias falsas, límite de presupuesto o salida no permitida mantienen el resultado por reglas. Se registra sólo la clase del fallo y las versiones, sin entrada ni salida libre. No se encadenan reintentos o llamadas de reparación sin consumir el presupuesto total acordado.

## Presupuesto inicial para medir

Valores propuestos para el primer experimento, pendientes de validar con el modelo elegido:

| Recurso | Propuesta |
|---|---|
| Entrada al modelo | Hasta 3.000 tokens incluyendo instrucciones, señales y contexto |
| Salida | Hasta 600 tokens y los límites de caracteres del schema |
| Tiempo de una llamada | Hasta 8 segundos; sin retener la evidencia inicial |
| Llamadas | Una por interpretación o turno admitido; sin reparación automática inicial |
| Plazo de enriquecimiento del caso | Hasta 12 segundos; al vencer, finaliza con la cobertura disponible |
| Costo | Tope configurable por operación y presupuesto global; importe pendiente de cotización y aprobación |

No se trunca a ciegas una URL o señal para cumplir el límite. Se priorizan hechos calculados y contexto reciente; si el caso no cabe de forma útil, se declara la limitación. El presupuesto de turnos y cuotas de cuenta sigue pendiente. Si el proveedor no permite estimar tokens o limitar consumo, se revisa el adaptador antes de habilitarlo.

El plazo total se propaga a las dependencias: la llamada dispone del menor tiempo entre su máximo y el restante del caso. Si no alcanza, se omite o cancela. No se descartan señales críticas para hacer caber una interpretación.

## Selección y evaluación

Comparar candidatos con el mismo conjunto de [evaluación](evaluation.md), instrucciones, presupuesto y snapshots. Medir errores peligrosos, falsos positivos, abstenciones, referencias inventadas, latencia y costo real por caso. La calidad del español y la comprensión de expresiones locales se comprueban en casos etiquetados y pruebas con usuarios.

Revisar conservación, uso para entrenamiento, subprocesadores, ubicación y configuración antes de enviar datos. La documentación contractual y la medición son necesarias para elegir; este contrato no selecciona proveedor ni promete compatibilidad idéntica entre APIs.

## Candidatos indicados por JP (17-oct-2026)

El adaptador llama al proveedor directamente por HTTPS desde Phoenix; no necesita Bedrock ni un SDK de OpenAI para adoptar un contrato HTTP compatible. Guardar proveedor, modelo solicitado y versión reportada junto a la evaluación reproducible. Un alias que cambia no equivale a una versión congelada.

Meta documenta que el contenido de la modalidad Contributor puede utilizarse para entrenar futuros modelos. Por ello, la propuesta limita `muse-spark-1.3-contributor` a casos sintéticos de evaluación hasta acordar expresamente ese tratamiento. La minimización no garantiza eliminar todos los datos personales. Ver [modalidades de Muse Spark](https://dev.meta.ai/docs/models).

`deepseek-flash` sigue como candidato para el producto. Antes de habilitar mensajes reales, contrastar condiciones específicas de la API sobre conservación, entrenamiento, transferencias y subprocesadores; una política del chat de consumo no acredita las condiciones de una integración. El identificador se contrasta en [los modelos de DeepSeek](https://api-docs.deepseek.com/api/list-models/). Todavía no se afirma una política de no entrenamiento ni se ha ejecutado la comparación de calidad/costo.
