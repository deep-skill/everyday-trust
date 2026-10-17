# Revisión de la documentación (Claude Code)

Estado: revisión del 17 de octubre de 2026, 15:35, sobre el estado de `docs/` a esa hora. La escribió la sesión de Claude Code que revisa el proyecto en paralelo. Son propuestas: las decisiones siguen siendo de JP.

## Lo que está sólido

- Trazabilidad de B01 a B08 desde negocio hasta arquitectura, datos y aceptación (`review.md`).
- Las reglas deciden primero y la IA no puede rebajar evidencia de alto riesgo.
- Procedencia de cada señal (`Source`, `SourceVersion`, `check_status`) y cuatro veredictos sin categoría de "seguro".
- Privacidad por diseño: sin mensaje original en el historial, logs sin contenido, minimización antes del modelo.
- Idempotencia, cuotas atómicas, errores acotados y cobertura parcial explícita.
- C4 con una sola fuente en Structurizr.

Ya incorporado tras revisar Scamio: señales antes de esperar a la IA, pregunta sobre clic, datos compartidos o pago, minimización de datos y resultado breve con evidencia ampliable.

## Brechas pendientes

Ordenadas por impacto en la evaluación técnica (complejidad, funcionamiento en vivo y calidad) y de producto (problema y claridad).

### 1. Los datos peruanos no están modelados

"Fuentes verificables" es una caja cerrada en el C4 y el modelo de datos solo tiene `Source` y `SourceVersion`. El diferencial del producto son esos datos y no aparecen.

Propuesta de entidades:

| Entidad | Campos esenciales | Nota |
|---|---|---|
| Brand | id, nombre, sector (banco, billetera, entidad pública, courier) | Solo marcas con fuente oficial |
| OfficialDomain | brand_id, dominio, source_version_id, verified_at | Una coincidencia valida el dominio, no al remitente |
| OfficialChannel | brand_id, tipo (código SMS, WhatsApp, teléfono, app), valor, source_version_id, verified_at | El remitente de un SMS se puede falsificar: coincidir es una señal neutra, no coincidir sube el riesgo |
| ThreatIndicator | tipo (dominio, host), valor, source_version_id, first_seen, last_seen, imitated_brand_id opcional | Phishing.Database, PhishTank y futuros reportes |
| RegulatoryNotice | nombre, modalidad, fecha del aviso, URL del comunicado, source_version_id | Entidades informales de la SBS, con fecha de corte |

Y un componente o contenedor de **ingesta de fuentes** en el C4: trabajos programados por fuente, validación, versión, exclusión para no duplicar y verificación manual para las listas oficiales.

### 2. El intérprete de IA no tiene contrato

El componente existe, pero falta un documento (por ejemplo `architecture/ai-interpretation.md`) con:

- Entrada: texto minimizado, señales calculadas y versión de política.
- Salida: esquema JSON (veredicto sugerido, tipo de estafa de un catálogo cerrado, explicación con largo máximo, ids de las señales citadas, respuesta de seguimiento).
- Validación: esquema estricto, solo ids de señales existentes, sin dominios ni números que no estén en la entrada.
- Defensa contra inyección: el mensaje va delimitado como dato, sin herramientas, y la salida nunca baja el piso de riesgo.
- Presupuesto: tokens de entrada y salida, tiempo máximo y costo por caso.
- Criterios para elegir modelo: calidad en español peruano, latencia, política de datos y costo, medidos con la evaluación del punto 3.

### 3. Falta el componente de evaluación

`product.md` define el indicador de falsos positivos y negativos, pero nada lo produce. Propuesta:

- Set etiquetado de 50 a 100 mensajes: sintéticos, alertas oficiales públicas y donados con consentimiento y anonimizados. Incluir mensajes legítimos de bancos.
- Etiquetas por veredicto y tipo de estafa.
- Un ejecutor que corra en CI y guarde resultados por versión de política y por modelo.
- Métricas: falsos negativos en alto riesgo (prioridad), falsos positivos en mensajes legítimos, latencia p50 y p95 y cobertura.

Sirve para elegir modelo, para la demo y para responder preguntas fuera del guion.

### 4. Falta la evidencia del problema

`product.md` deja las cifras para después. Hay datos abiertos que ya se procesaron: según el [dataset de delitos informáticos del Ministerio Público](https://www.datosabiertos.gob.pe/dataset/delitos-inform%C3%A1ticos-denunciados-ante-el-ministerio-p%C3%BAblico-mpfn), en 2025 hubo 29.342 denuncias por fraude informático y 10.559 por suplantación de identidad. Son cálculos propios sobre el CSV: revisar el script antes de publicarlos.

### 5. Números de teléfono como entrada

La primera entrega se limita a texto y enlaces, pero el prototipo ya analiza números y comparar contra los canales oficiales de cada marca es parte del diferencial. Recomendación: mantener los números en el alcance, sin conservarlos en historial ni logs, como ya establece B07.

### 6. Tokens de sesión y estado temporal

- Tokens de Cognito en la web: que el servidor de la web los guarde en una cookie httpOnly y los pase a la API (patrón backend for frontend). Nunca en `localStorage`. Mantener el chequeo de origen.
- Estado temporal de casos y cuotas: en la primera versión, PostgreSQL con `expires_at` y limpieza programada, para no sumar otro servicio. Redis o ElastiCache cuando haya varias réplicas con carga real.

### 7. Vista de despliegue

Ya está anotada como pendiente. Cuando se cierre el stack: vista de despliegue C4 con entrada HTTPS, límites de confianza, red privada de datos, salida a fuentes externas y dónde vive cada secreto.

### 8. Wireframe del resultado

Comprobar que la tarjeta muestre el veredicto como titular ("Alto riesgo: posible suplantación de BCP") y, como acción principal, el canal oficial de la marca.

### 9. Alcance del evento frente a arquitectura objetivo

Una tabla en `docs/README.md` con tres columnas: lo que estará en vivo en la entrega, la arquitectura objetivo y lo que quedó fuera con su motivo. Responde de antemano qué se construyó, por qué y qué se dejó.

## Lo que pesa menos

La marca (contraste comprobado, nombres razonables) y el VSM (honesto en que sus tiempos son hipótesis) están bien como están. Lo que destraba la implementación son las decisiones listadas en `review.md`: lenguaje de la API, identidad y proveedor de IA.

## Segunda revisión (17-oct, 15:55)

Sobre `source-ingestion.md`, `ai-interpretation.md`, `evaluation.md`, `business/evidence.md` y la tabla de alcance de `README.md`, después de la respuesta de `review.md`.

Lo sólido: publicación atómica con staging y revisión manual de catálogos oficiales; vencimiento de fuentes sin convertir ausencia en legitimidad; salida de IA con esquema estricto, ids citados y acciones tomadas solo de un catálogo curado (el modelo no puede inventar teléfonos ni enlaces); el error peligroso como métrica prioritaria; separación entre casos de ajuste y conjunto reservado; la evidencia del MPFN con método y checksum.

### 10. La IA no puede subir el riesgo sin una señal determinista

El paso 5 de la validación exige evidencia citada o una regla validada para elevar el riesgo. Así, el modelo no puede detectar estafas solo de texto, sin enlace ni marca ("Hola mamá, cambié de número, yapéame 500 urgente"), que es justo el caso donde las reglas se quedan cortas.

Propuesta asimétrica: el modelo puede subir hasta `suspicious` por sí solo, con `scam_type` y la explicación marcada como interpretación; llegar a `high_risk` sigue exigiendo una señal citada o un patrón validado; nunca baja del piso. La evaluación mide los falsos positivos que esto agregue.

### 11. El catálogo de `scam_type` no tiene los tipos locales

Faltan los patrones que diferencian el producto en Perú y que cambian la acción recomendada:

| Tipo propuesto | Ejemplo | Acción distinta |
|---|---|---|
| `family_emergency` | "Mamá, cambié de número, necesito plata" | Llamar al número que ya conoces |
| `mistaken_transfer` | "Te yapeé por error, devuélvemelo" | Revisar el movimiento en la app, no devolver a otro número |
| `fake_loan` | Préstamo inmediato con adelanto | Consultar la lista de informales de la SBS |
| `job_task_scam` | Pago por likes o tareas | No pagar para "liberar" ganancias |
| `prize_or_raffle` | Premio o sorteo con cobro | No pagar por recibir un premio |
| `extortion` | Amenazas o cobro de cupos | Central 111 y denuncia |

### 12. Falta la entidad de políticas oficiales de cada marca

`source-ingestion.md` admite que una contradicción con una política oficial explícita produzca una advertencia, pero el modelo de datos no tiene dónde guardarla. Los bancos y billeteras publican frases del tipo "nunca te pediremos tu clave por SMS o WhatsApp".

Propuesta: `BrandPolicy` (brand_id, enunciado, canales a los que aplica, dato que nunca se solicita, source_version_id, verified_at, status). Es barata de curar, verificable con la página oficial y produce una señal fuerte y citable: "El BCP indica que nunca pide tu clave por SMS; este mensaje la pide".

### 13. Primer feed de amenazas

Para destrabar "el feed concreto se acuerda tras verificar acceso y condiciones": Phishing.Database tiene licencia MIT, se descarga sin llave desde GitHub (unos 392.000 dominios, incluidos falsos BCP e Interbank y 249 `.pe`, revisado el 17-oct). PhishTank cerró el registro de usuarios nuevos y limita las descargas sin llave.

### 14. Evidencia del problema: una cifra de personas

El MPFN cuenta denuncias. La ENAPRES del INEI (boletín feb-jul 2026, preliminar) estima que el 3,6% de la población urbana de 15 años a más fue víctima de un delito informático, frente al 2,3% un año antes. Mide personas, no denuncias, y complementa la cifra del MPFN con la advertencia de que es preliminar.

### 15. La tabla de alcance del evento no tiene orden de corte

La columna del evento tiene siete compromisos sin prioridad. Si el tiempo no alcanza, conviene saber de antemano qué se corta primero. Propuesta para que JP decida: P0 consulta anónima con evidencias, un feed e interpretación de IA; P1 cuenta e historial; P2 informe de evaluación completo y números con entrada dedicada.
