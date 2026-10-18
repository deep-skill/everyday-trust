# Revisión de la definición antes de programar

Estado: revisión documental parcial, 17 de octubre de 2026. Los borradores todavía requieren decisiones de JP. Este registro distingue comprobar los artefactos de aprobar el producto y la arquitectura.

## Trazabilidad de requisitos

| ID | Recorrido | Responsabilidad técnica | Datos | Comprobación de aceptación |
|---|---|---|---|---|
| B01 | Consulta anónima | API de casos y señales | Caso temporal | Ventana privada, sin pantalla de acceso obligatoria |
| B02 | Entender el resultado | Señales y política de riesgo | Evidencia, cobertura y revisión | Cuatro veredictos; pendientes y fallos distinguibles; advertencia inicial no retenida por la IA |
| B03 | Aclarar lo ocurrido | Casos e interpretación | Contexto minimizado o resumen guardado | Ayuda según clic, datos compartidos o pago; fallo de IA sin rebajar el piso de riesgo |
| B04 | Crear cuenta y volver | Identidad y acceso | Perfil externo | Registro, confirmación, recuperación, salida y retorno al caso |
| B05 | Guardar, retomar y borrar | Historial y titularidad | SavedCase y CaseEvidence | Dos cuentas no pueden acceder a los casos de la otra; borrado consistente |
| B06 | Mayor uso con cuenta | Control de cuotas | QuotaBucket | Solicitudes concurrentes no superan el presupuesto autorizado |
| B07 | Controlar lo conservado | Minimización, saneamiento y vencimiento | Contexto permitido y resumen durable | Secretos sintéticos no llegan al modelo ni al estado temporal; original, números y rutas no aparecen en historial ni logs |
| B08 | Medir funcionamiento y retorno | Métricas de operación | Agregados y claves con duración acotada | Se distinguen uso, pruebas, errores, reintentos y utilidad percibida; feedback no equivale a precisión |

## Respuesta a la revisión de Claude

La [revisión del 17-oct](review-claude.md), con entregas a las 15:35 y 15:55, se conserva como evidencia de los estados que evaluó. Esta respuesta incorpora definiciones y propuestas; no acredita ejecución ni cierra decisiones de JP.

| Punto | Resolución documental | Estado real |
|---|---|---|
| 1. Datos peruanos e ingesta | [Catálogos en datos](architecture/data-model.md#catálogos-de-verificación), [ingesta](architecture/source-ingestion.md), ER y componente C4 | Modelados como borrador; faltan carga, curación y publicación. Ausencia de remitente en catálogo no implica fraude |
| 2. Contrato de IA | [Entrada, salida, validación y presupuesto](architecture/ai-interpretation.md) | Propuesta agnóstica; proveedor, modelo y presupuesto monetario pendientes |
| 3. Evaluación | [Corpus, ejecutor e informes](architecture/evaluation.md), evaluador en C4 | Diseño documentado; corpus completo, ejecutor e integración CI pendientes |
| 4. Evidencia del problema | [Cálculo MPFN](business/evidence.md) y contexto en negocio | Script revisado y suma reproducida por dos métodos; no se renovó la descarga por 403 del portal |
| 5. Números | [Alcance](business/product.md#alcance-de-la-primera-entrega) distingue extracción en texto de búsqueda dedicada | Se propone conservar lo existente. Titularidad y listas de acusaciones no se ofrecen; comparación de remitentes por validar |
| 6. Sesiones y temporalidad | [Stack](architecture/stack-decision.md) propone BFF con cookie opaca y tokens en servidor; PostgreSQL para temporalidad si se elige ese motor | Pendiente de JP. PostgreSQL puede compartir estado entre réplicas; no se exige Redis por ese solo motivo |
| 7. Despliegue | Se mantiene la vista física como requisito al acordar servicios | Pendiente; no dibujar como implementada una infraestructura sin validar |
| 8. Tarjeta de resultado | [Experiencia](design/experience.md) y [wireframe](diagrams/rendered/wireframe-consultation.svg) usan veredicto como titular y canal oficial curado como acción | Esquema sintético; no un resultado real ni una pantalla implementada |
| 9. Evento y objetivo | [Tabla de alcance](README.md#entrega-del-evento-y-arquitectura-objetivo) separa propuesta, objetivo y diferidos | Compromiso por validar; no se anuncia como en vivo |
| 10. Elevación sólo por IA | [Política asimétrica](architecture/ai-interpretation.md#validación-y-aplicación-de-política): puede elevar hasta sospechoso sin enlaces ni señales de reglas, indicando interpretación | Corregida la restricción excesiva del borrador. Alto riesgo necesita sustento adicional; el piso determinista se conserva |
| 11. Tipos de patrón | [Catálogo](architecture/ai-interpretation.md#catálogo-de-patrones) incluye familiar, transferencia por error, préstamos, tareas, premios y extorsión | Hipótesis de modalidad, no etiquetas de fraude probado. Acciones sujetas a curación y foco inicial |
| 12. Políticas de marca | `BrandPolicy` en [datos](architecture/data-model.md), ER e [ingesta](architecture/source-ingestion.md) | Modelado; falta curar registros. Aplicar sólo con marca, canal, pedido y condiciones compatibles; excluir negaciones y citas educativas |
| 13. Primer feed | Phishing.Database como candidato preferido; licencia MIT contrastada y checksum de copia en [ingesta](architecture/source-ingestion.md#primer-feed-propuesto) | Falta validar frescura e integrar. La fecha de descarga no prueba vigencia |
| 14. Personas y denuncias | [INEI ENAPRES](business/evidence.md#personas-estimación-enapres-del-inei) complementa MPFN | Tabla y notas comprobadas: preliminar, población urbana de 15 o más años y referencia de victimización de doce meses |
| 15. Orden de corte | [P0/P1/P2](README.md#orden-de-ejecución-y-recortes-propuestos) conserva cuenta e historial en P1 y recorta primero ampliaciones P2 | Propuesta por validar. Evaluación mínima permanece en P0; informe completo y comparación de modelos pueden ampliarse después |

Prioridad propuesta antes de programar: cerrar stack/sesión y el primer corte; validar catálogos, contrato y criterios de evaluación. Se mantienen las decisiones de JP de incluir cuenta e historial y validar la documentación primero. Las propuestas de la revisión no autorizan por sí solas una migración, nuevas dependencias o despliegues.

## Comprobaciones realizadas

- Fuentes PlantUML renderizadas para VSM, wireframes, datos y secuencias.
- Workspace validado con Structurizr 2026.09.19; vistas C4 exportadas a PlantUML y SVG. Tras la confirmación de stack se añadió la vista AWS de despliegue, renderizada e inspeccionada visualmente. Esto no valida recursos reales.
- Inspección visual de VSM, consulta, revisión en curso, modelo de datos, secuencia de análisis y componentes C4 tras los ajustes de Scamio. Contexto y contenedores también tuvieron una revisión visual inicial.
- Enlaces locales de los documentos revisados.
- Contraste de los seis colores de texto y estado comprobado sobre blanco y fondo propuesto; falta validar componentes y pantallas finales.
- Revisión de Scamio contrastada con fuentes oficiales; límites de lo inferido del código público y capacidades no probadas documentados en [la nota de revisión](business/scamio-review.md).
- Revisión de Claude respondida por punto; catálogos, ingesta, contrato de IA, evaluación y alcance del evento documentados como borradores. ER de fuentes y vistas C4 regeneradas e inspeccionadas visualmente.
- Cálculo MPFN 2025 reproducido tras leer el script y contrastado con una suma independiente; periodo, unidad y checksum en [evidencia](business/evidence.md).
- Segunda revisión respondida, con política asimétrica de IA, catálogo de patrones, `BrandPolicy` y orden de prioridades propuesto. Licencia de Phishing.Database contrastada; el conteo local detecta valores duplicados antes de normalizar.
- Cuadro resumen, notas y periodo de referencia de ENAPRES contrastados en el boletín del INEI; no se confunden semestre de entrevistas y doce meses de victimización.

Estas comprobaciones no equivalen a una prueba de funcionamiento del backend ni a conformidad completa de accesibilidad.

## Decisiones confirmadas el 17-oct-2026

JP confirmó SvelteKit/TypeScript/Tailwind, Elixir/Phoenix, PostgreSQL, Cognito y BFF con sesión opaca HttpOnly y tokens del proveedor en servidor. Indicó IA por API directa, con Muse Spark 1.3 Contributor o `deepseek-flash` como candidatos. Tras considerar BD en EC2, JP eligió RDS PostgreSQL. Toda operación de infraestructura se documenta en `devops-agents`.

La [decisión de stack](architecture/stack-decision.md) registra esa aprobación y la [propuesta de despliegue](architecture/aws-deployment.md) concreta EC2 con Docker Compose, RDS privado, Nginx, Cloudflare Tunnel y Actions/GHCR. Las filas de la respuesta a Claude conservan lo propuesto en aquella revisión; esta sección actualiza su estado. No acredita recursos creados, integración de modelos ni una nueva aprobación de compra de dominio.

## Decisiones que faltan

1. Validar conservación de resúmenes y duración de sesiones, casos y backups.
2. Confirmar tamaño/costo del EC2, punto de entrada Cloudflare, dominio y condiciones operativas sobre la propuesta concreta; implementar y verificar recuperación.
3. Completar contrato OpenAPI y ejecución de trabajos con plazo y recuperación ante reinicios.
4. Revisar la pantalla representativa. JP eligió ¿Es estafa? y «Revisa antes de responder» y aprobó provisionalmente la identidad visual 0.1 (logo, favicon, paleta y tipografía). La propuesta móvil/escritorio sigue para revisión en [branding](design/brand.md), todavía sin integrar a la app.
5. Elegir entre los dos candidatos de IA, revisar las condiciones específicas de API y definir cuotas y presupuesto. Muse Contributor permite uso de contenido para entrenamiento; no se publica una garantía contraria.
6. Validar la entrega por etapas y los ajustes de Scamio del primer corte; cuenta e historial permanecen solicitados, capturas/QR/reportes/compartir siguen fuera.

## Primer bloque de implementación tras la validación

El primer corte debe entregar una consulta pública completa en la infraestructura acordada. Después incorpora acceso, guardado voluntario e historial mediante la misma API. El orden exacto y la convivencia con el prototipo se fijan al cerrar el stack; este documento no autoriza por sí solo commits, creación de repos públicos ni despliegues.

## Respuesta a tercera revisión, 17-oct

Se implementaron IP confiable en el BFF y Nginx, RDAP directo desde IANA, reserva de turnos sin mantener una conexión durante la IA, enum y prompt alineados, interpretación asíncrona con abstención al vencer, agregados B08 separados de demos, conservación del riesgo ante timeouts, cuotas conjuntas, redacción de códigos cortos, bloqueo Contributor en producción, configuración obligatoria y conservación de sesiones ante fallos transitorios. Cognito se aprovisiona con managed login v2 para permitir reautenticación explícita. Su comportamiento debe probarse contra AWS antes de declararlo validado.

El feed importado localmente contiene 391.548 hosts distintos, publicado el 2-oct y descargado el 17-oct en Lima. Su evidencia es histórica y su cobertura parcial. La actualización sigue siendo una operación explícita y documentada, no se afirma que exista un job automático.
