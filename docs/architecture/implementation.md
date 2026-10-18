# Estado actual de implementación

Corte de documentación: 18-oct-2026. Web pública: [verifica.deepskill.space](https://verifica.deepskill.space/). Producción conserva el corte `eb52376`, publicado por [Actions/SSM](https://github.com/deep-skill/everyday-trust/actions/runs/39128376484). La limpieza del prototipo y la documentación de cierre son cambios del repositorio, sin nuevo despliegue.

## Qué está construido

| Área | Implementación |
|---|---|
| Web | SvelteKit, TypeScript y Tailwind; portada explicativa, guía separada y resultado con motivos, cobertura y siguiente acción |
| API | Phoenix 1.8.15, Elixir 1.18.4/OTP 27; contrato `/api/v1/*`, credencial interna y autorización por titular |
| Consulta | Texto/enlaces sin cuenta; señales verificables, sitios, feed e interpretación asíncrona con seguimiento acotado |
| Cuenta | Cognito con Code/PKCE S256, state y nonce; sesión opaca HttpOnly/Secure/SameSite=Lax y tokens cifrados en servidor |
| Continuidad | Guardado voluntario e idempotente por cuenta/caso, historial privado, paginación y borrado |
| Tracción | Visitas aproximadas por sesión/día, consultas y valoraciones agregadas; demos excluidas de consultas y reseñas |
| Reseñas | Una valoración por caso completado; comentario privado opcional hasta 500 caracteres, fuera de IA, retención de 30 días y borrado con cuenta |
| Datos | RDS PostgreSQL privado; rol y esquema propios del BFF, rol de API separado y credencial distinta de migración |

El BFF valida origen y cuerpo antes de reenviar; el navegador no puede elegir el propietario. `/api/analyze` devuelve 410 y el motor TypeScript del prototipo se retiró del repositorio. Las reglas de producción y sus pruebas viven en Phoenix.

## Análisis, sitios y modelo

La creación entrega las señales disponibles tras comprobaciones de red concurrentes y acotadas. Cuando hay IA pendiente, la web consulta el mismo caso hasta finalizar. Las revisiones son monotónicas; el plazo exterior del caso es de 8 segundos y cada petición web admite hasta 12 segundos. Reintentar una creación puede consumir otra consulta: no se afirma idempotencia de creación.

<a id="comprobación-de-sitios-y-contributor-corte-local"></a>
### Comprobación de sitios y Contributor

La API consulta mediante HEAD sólo la raíz de sitios arbitrarios: omite ruta, query, fragmento, cookies y credenciales. Resuelve IPv4 públicas, fija la IP validada y conserva hostname/SNI y validación TLS. Revalida redirecciones y bloquea redes privadas, loopback, metadata AWS, IPv6, puertos distintos de 80/443 y bajadas HTTPS a HTTP. No descarga HTML ni ejecuta JavaScript. Los acortadores permitidos conservan una resolución acotada del enlace completo; los hosts intermedios también se comparan con el feed.

Muse Spark 1.3 Contributor está activo durante el piloto. Recibe el mensaje original completo y todo el análisis; las preguntas se envían completas con el resultado disponible. El original sólo vive en memoria durante el procesamiento, fuera de PostgreSQL, historial y logs. La advertencia de omitir datos personales no equivale a una minimización antes del modelo. [Contrato de IA](ai-interpretation.md).

El modelo no tiene herramientas. Sólo se consumen categorías, ids existentes e intenciones de un contrato cerrado. Títulos, explicaciones y acciones visibles proceden de contenido revisado en servidor. Ninguna salida reduce el riesgo de reglas y una elevación sólo interpretativa llega como máximo a sospechoso. JSON inválido, presupuesto agotado o timeout mantienen señales y declaran cobertura incompleta, sin reintentos automáticos de IA.

## Fuentes y cobertura

La API combina el catálogo de dominios oficiales, RDAP y Phishing.Database. La ingesta valida tamaño, hosts, cantidad, descenso anómalo y SHA-256; publica una versión atómica bajo exclusión PostgreSQL, sin visitar dominios denunciados.

El snapshot cargado tiene 391.548 hosts, fue publicado el 2-oct-2026 y descargado el 17-oct. Se trata como histórico aunque la descarga sea reciente. La coincidencia es por host exacto; una ausencia de coincidencias o una fuente incompleta no habilitan por sí solas un resultado sin señales. Un conflicto con el catálogo oficial exige revisión. [Fuentes e ingesta](source-ingestion.md).

## Sesión, persistencia y borrado

Cognito y la API validan firma, emisor, cliente y clase del token. El BFF verifica audiencia y nonce del ID token. Los tokens se cifran con AES-256-GCM y la renovación se serializa mediante bloqueo de fila. Los intentos de acceso vencen a los 10 minutos y la sesión de cuenta dura como máximo 7 días. La clave de cifrado vive fuera de PostgreSQL; rotarla invalida sesiones en este corte.

Los casos temporales duran una hora, prorrogable por seguimiento hasta cuatro horas desde su creación. El vencimiento se comprueba al leer y una limpieza periódica retira filas vencidas. Sólo se conserva el contexto permitido; los resúmenes no incluyen original, números, emails ni rutas/query de enlaces. Cada lectura y borrado verifica titularidad.

Eliminar la cuenta exige autenticación de los últimos cinco minutos. Borra datos de aplicación, bloquea la identidad mediante un hash de control y solicita eliminación en Cognito. Un fallo devuelve `identity_deletion_pending` y permite reintentar sin reabrir los datos. Las marcas completadas vencen a las 24 horas; las pendientes requieren reconciliación. Los agregados de tracción sobreviven sin texto ni identidad.

## Límites de seguridad y consumo

| Control | Límite vigente |
|---|---|
| Entrada | 5.000 caracteres en API y 32 KiB de cuerpo en Nginx/BFF |
| Nginx | 3 r/s por IP, ráfaga 15; 30 r/s globales, ráfaga 60; 10 conexiones por IP |
| Consultas por día UTC | 5 anónimas o 25 con cuenta; 200 por red y 1.000 globales |
| Seguimiento | 5 por caso; 10 anónimos o 50 con cuenta por día |
| IA | 200 llamadas globales/día entre análisis y preguntas, entrada hasta 65.536 bytes con instrucciones y salida de 600 tokens; conexión de 1 s y respuesta de 6 s |
| Trabajo de análisis | Hasta 20 tareas supervisadas; no es un límite global de toda pregunta síncrona |
| Valoraciones por día | 3 por sujeto, 60 por red y 500 globales; una por caso |

Las preguntas genéricas reconocidas se orientan localmente sin consumir IA. El filtro no es infalible; la salida del modelo sigue limitada a intenciones cerradas. Las cuotas no son un presupuesto monetario duro ni una garantía frente a DDoS. [Revisión completa](security-review.md) y [reporte de vulnerabilidades](../../SECURITY.md).

## Cómo se despliega

Cloudflare Tunnel mantiene una conexión saliente a EC2 sin puertos entrantes. Nginx sirve como entrada interna a la web/BFF; Phoenix sólo es accesible desde la red de aplicación. RDS es privado y las conexiones verifican CA y hostname. La configuración de producción exige identidad, secretos y origen HTTPS antes de arrancar.

Actions ejecuta checks y publica imágenes amd64 por digest en GHCR, con SBOM y provenance. El deploy usa credenciales temporales OIDC y SSM, un manifiesto privado y migraciones separadas de los roles de ejecución. La operación canónica, Compose/Nginx, inventarios, secretos por referencia y procedimientos viven en `devops-agents`. [Arquitectura AWS](aws-deployment.md).

## Pruebas y evidencia

La suite vigente combina pruebas Phoenix y pruebas web de cifrado de sesión; consultar CI para el total del corte. Phoenix cubre reglas, redirecciones, JWT, cuotas concurrentes, aislamiento, borrado, reseñas, métricas e ingesta. CI exige formato, compilación sin advertencias, migraciones y pruebas de API, además de tipos, build y pruebas de la web.

La evaluación incluida en ExUnit ejecuta 24 fixtures sintéticos offline: 0 verdes peligrosos, 0 falsas alarmas y 6 abstenciones. No mide precisión real ni calidad del modelo. [Método](evaluation.md) e [informe](evaluation-report.json).

La suite de navegador acreditó previamente 29 comprobaciones con identidad simulada y una base separada; no se repitió completa en este cierre. Otras 12 comprobaciones usaron Cognito y RDS reales. En navegador privado se comprobaron acceso Cognito, análisis, guardado y lectura del historial. El logout actual usa POST propio con respuesta JSON y navegación a Cognito validada por servidor; pasó las comprobaciones HTTP de origen, sesión y redirección. Falta repetir visualmente ese último recorrido.

La verificación pública del corte desplegado comprobó HTTPS, headers dinámicos, consulta demo, valoración idempotente, comentario privado y retirado, aislamiento entre sesiones y presentación. Las pruebas sintéticas se separan de tracción y sus identidades desechables se eliminaron. La presentación tiene cinco slides HTML y assets con versión de contenido; no se modifican durante esta limpieza.

## Límites y pendientes

- Restauración de backups y reconciliación de borrados sin ejercicio; alta, confirmación y recuperación con correo real sin probar.
- Repetición visual final del logout corregido pendiente. Las comprobaciones HTTP no se presentan como recorrido completo de navegador.
- Sin Turnstile, presupuesto monetario duro del proveedor ni ensayo de carga verificados; no se afirma una regla WAF personalizada.
- CSP y otras cabeceras pendientes de equiparar en recursos estáticos. Este cierre no modifica hooks, Nginx ni Cloudflare.
- EC2 único y RDS Single-AZ; CloudWatch tiene un grupo de logs creado, sin alarmas completas.
- Comparación de calidad/costo de modelos, proveedor y datos para difusión general pendientes. Capturas, QR, extensión y agentes de PC/celular son roadmap.

El [historial de cortes y verificaciones](../archive/implementation-history.md) se conserva como archivo histórico, separado de este estado actual.

## Integraciones opcionales

Safe Browsing, urlscan, reporte voluntario, capturas y comunidad están implementados detrás de cinco flags apagados por defecto. El contrato, las cuotas y los criterios de activación están en [integraciones del piloto](pilot-integrations.md). La presencia del código no acredita que el proveedor esté activo en producción.
