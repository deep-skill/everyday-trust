# Historial de implementación, hasta el 18-oct-2026

> Archivo histórico. Las decisiones, cifras y pendientes de cada corte describen su momento y no el estado actual. Consultar [implementación vigente](../architecture/implementation.md).

# Implementación del primer corte

Estado: implementación y despliegue AWS público, 18-oct-2026, con Contributor activo para el piloto autorizado. Web: [verifica.deepskill.space](https://verifica.deepskill.space), servida mediante Cloudflare Tunnel sin puertos entrantes en EC2. La API es Phoenix 1.8.15 sobre Elixir 1.18.4/OTP 27; la web usa SvelteKit y adapter-node. PostgreSQL local sirve para desarrollo y pruebas; producción usa RDS privado. Los apartados finales registran los cortes sucesivos y la activación vigente.

## Recorrido implementado

`Navegador → SvelteKit/BFF → Phoenix → PostgreSQL`

El BFF expone `/api/v1/*`, valida el origen de las escrituras y limita cuerpo antes de reenviar. Phoenix requiere además una credencial de servicio interna y valida por separado el access token Cognito cuando existe. Los identificadores de visitante son aleatorios y los de red se seudonimizan con HMAC; el cliente no elige al propietario. El endpoint anterior `/api/analyze` responde 410. El motor TypeScript queda sólo como referencia de regresión y no forma parte del camino de producción.

Cada consulta devuelve primero señales tras hasta cinco comprobaciones de red concurrentes y acotadas. Si hay IA aprobada, devuelve estado pendiente y la web consulta la finalización, con revisión monotónica y plazo de ocho segundos. La web espera hasta 12 segundos para cada petición; un reintento de creación puede consumir otra consulta. El guardado es idempotente por cuenta y caso temporal. No se afirma idempotencia de creación.

Las respuestas de IA sólo seleccionan categorías, ids de señales existentes e intenciones de seguimiento. Las explicaciones persistentes y las acciones se producen en servidor con texto revisado. No se conservan párrafos libres del modelo ni se aceptan teléfonos o enlaces de ayuda generados. Una elevación sólo por interpretación llega como máximo a sospechoso; ninguna salida rebaja el piso verificable.

## Cuenta, datos y límites iniciales

En desarrollo, la consulta anónima no necesita Cognito configurado. La imagen de producción exige la configuración completa antes de arrancar. Registro, verificación y recuperación se delegan a la interfaz gestionada de Cognito. El acceso usa Authorization Code, PKCE S256, state de un solo uso y nonce. Web y API validan firma RS256, issuer, clase de token y cliente; la web comprueba también audiencia y nonce del ID token. Los tokens se cifran con AES-256-GCM en `bff.web_sessions`; el navegador recibe una cookie opaca Secure/HttpOnly/SameSite=Lax. La renovación se serializa con un bloqueo de fila y admite rotación de refresh token.

Los intentos de acceso vencen a los diez minutos y la sesión de cuenta tiene siete días de duración máxima. La clave de cifrado es externa a PostgreSQL; su rotación en este corte invalida las sesiones, sin un anillo de claves. Los roles de ejecución de API y BFF se separan de las credenciales de migración en producción. Las pruebas locales usan credenciales exclusivamente de desarrollo.

Valores iniciales de implementación, configurables mediante una revisión posterior de política: cinco consultas anónimas y 25 con cuenta por día UTC; cinco seguimientos por caso, con topes diarios de 10 y 50 respectivamente; 200 análisis por red y 1.000 globales por día; 200 llamadas de IA globales por día. Son límites de operaciones, no un sistema de facturación. El proveedor conserva sus propios límites y presupuesto. El input de Contributor se rechaza si contexto estructurado e instrucciones superan65.536 bytes UTF-8; el adaptador alternativo conserva3.000 bytes; máximo de salida de 600 tokens.

Los casos temporales vencen tras una hora, prorrogable por seguimiento hasta cuatro horas desde su creación. El vencimiento se comprueba al leer; una limpieza cada minuto elimina filas vencidas. No se persiste el mensaje original, números, emails ni rutas/query de enlaces. El contexto almacenado sólo contiene la evaluación permitida. Los resúmenes se guardan por elección y tienen lectura/borrado por propietario, con paginación de 20 elementos.

Eliminar la cuenta exige autenticación de los últimos cinco minutos: borra datos de aplicación, bloquea la identidad mediante un hash de control y solicita `DeleteUser` a Cognito. Si el proveedor falla, devuelve `identity_deletion_pending` y permite reintentar la eliminación sin reabrir el acceso a datos. No se comunica éxito del proveedor antes de recibirlo. Las marcas completadas se limpian tras 24 horas; las pendientes requieren reconciliación. RDS tiene backups automáticos de siete días y protección de borrado. La restauración y reconciliación de borrados siguen pendientes de ejercicio.

## Feed y disponibilidad

La ingesta es un comando operativo, fuera del tráfico de consultas. Requiere archivo de hasta 50 MB, SHA-256, fecha de descarga y fecha de publicación. Valida hosts, cantidad mínima, descenso anómalo y publica atómicamente bajo exclusión PostgreSQL. No visita los dominios denunciados. La coincidencia es por host exacto. Un conflicto con el catálogo oficial se marca para revisión y bloquea un resultado sin señales.

Una descarga vence tras 48 horas; una publicación de más de siete días se trata como histórica y su reporte tiene peso medio, con cobertura parcial. Publicaciones de más de 30 días no se admiten al importar. Una ausencia de coincidencia en una fuente histórica o no disponible no habilita el resultado verde.

El snapshot inspeccionado corresponde al commit público `12a20bf8dd2b7e78d9d38fc12b3e5c970f79d1a7`, publicado el 2-oct-2026. Se volvió a descargar el 17-oct por la noche y se comprobó su hash Git y SHA-256 `70c6c2e24e6b3484e7ace27b079723e55937bc1f4cbd98bea38a472ec8e37326`. La descarga reciente no actualiza la antigüedad de publicación. No se anuncia como una lista vigente del día.

## Integraciones y comprobación

Los adaptadores directos de DeepSeek Flash y Muse Spark Contributor están escritos, con validación de salida y fallback por señales. JP entregó una llave Meta y pidió Contributor; se comprobó con ejemplos ficticios. JP confirmó Contributor para el evento. JP pidió posteriormente contexto completo: mensaje original y resultado íntegro de comprobaciones; preguntas completas con el resultado disponible. Se retiró la reducción a códigos. Las acciones tras clic/datos/pago siguen locales; otras preguntas usan clasificación de intención. La credencial está cifrada y JP autorizó expresamente la activación en la URL pública sin login, comprobada el18-oct. Las comprobaciones del equipo usan datos ficticios. La orientación sin IA usa intenciones y acciones cerradas y lo indica en el resultado.

Las regresiones originales del motor de referencia y las pruebas Phoenix se ejecutan sin red externa. La suite de navegador usa la web compilada, PostgreSQL y JWT RSA de un proveedor simulado que fuerza renovación y rotación. No equivale a una prueba de Cognito real ni envía emails/SMS. Sus helpers sólo se cargan expresamente y se excluyen de las imágenes de producción.

CI y publicación manual de imágenes GHCR tienen actions fijadas a commits. La ejecución remota, publicación de paquetes, AWS, Cloudflare y pruebas de restauración se registran por separado en `devops-agents`. Las operaciones de producción están centralizadas allí.

## Correcciones de la tercera revisión

La API retorna las señales tras sus comprobaciones acotadas. Cuando se habilita un proveedor aprobado, la interpretación se ejecuta en una tarea supervisada con máximo 20 tareas simultáneas. La tarea Contributor captura el texto original sólo en memoria para enviarlo junto a las comprobaciones; el adaptador alternativo mantiene minimización. No se persiste el mensaje ni se registran payloads. La consulta queda `in_progress`, revisión 1, y el cliente consulta el resultado hasta `completed`, revisión 2. Tras ocho segundos, una lectura o la limpieza periódica finaliza un trabajo perdido con IA no disponible. No hay reintentos de llamadas facturables ni resultados verdes si la interpretación queda incompleta. Un reinicio puede perder la interpretación, conservando la evaluación por señales.

Las reservas de cuotas de sesión, red y servicio se hacen en una transacción corta y se revierten juntas. Los turnos se reservan atómicamente y la llamada externa ocurre fuera de la transacción. El proxy obtiene la IP desde el único salto Nginx confiable: `ADDRESS_HEADER=x-forwarded-for`, `XFF_DEPTH=1`. Nginx reemplaza ese encabezado desde Cloudflare, y EC2 carece de entradas públicas.

RDAP utiliza el bootstrap IANA versionado en `api/priv/catalog/rdap-bootstrap.json` y consulta directamente el registro HTTPS correspondiente. RDAP no visita la URL de la persona ni sigue redirecciones generales. Por separado, el nuevo comprobador HEAD del corte local sí consulta raíces públicas con restricciones descritas abajo. La falta de soporte o respuesta se presenta como cobertura parcial.

`daily_metrics` conserva conteos agregados por día UTC y distingue consultas y demostraciones. Registra finalizaciones, consultas adicionales en una sesión o cuenta, opiniones y errores de solicitudes recibidas por el controlador de creación. No mide personas únicas ni todos los errores de la infraestructura. Las opiniones agregadas sobreviven a la limpieza del caso temporal. Los ejemplos de la interfaz se reconocen en servidor y quedan separados de la tracción. `GET /api/v1/stats` expone sólo estos agregados.

El contenedor web exige configuración de identidad, origen HTTPS, cifrado y CA de RDS antes de arrancar. Phoenix exige la misma identidad y, para Meta, `AI_INPUT_MODE=full_context` para el piloto de hackathon. Un fallo transitorio de renovación conserva la sesión y devuelve indisponibilidad, sin convertirla silenciosamente en anónima.

AWS está aprovisionado y el despliegue pasó por GitHub Actions con OIDC y SSM. Cognito usa Essentials, rotación de refresh tokens y managed login v2. El primer stack vacío falló por incompatibilidad entre Lite y rotación, se verificó que no tenía usuarios y se eliminó antes de recrearlo. Cloudflare Tunnel ya proporciona la entrada pública. El recorrido OIDC completo en navegador contra AWS sigue pendiente. Doce comprobaciones privadas con dos identidades Cognito reales y RDS verificaron JWT, aislamiento, guardado, feedback, borrado de consultas y eliminación de ambos usuarios en Cognito, sin emails/SMS.

Verificación de la versión publicada: 67 pruebas Phoenix, 45 pruebas Node y 29 comprobaciones de navegador. El refinamiento local posterior añade comprobaciones descritas al final.

## Verificación AWS privada

GitHub Actions desplegó imágenes amd64 fijadas por digest a través de OIDC y SSM. RDS privado verifica TLS/CA y separa roles de API, BFF y migración. RDS y Cognito tienen protección de borrado activa. Las credenciales temporales de bootstrap y GHCR se eliminaron al completar la operación.

El catálogo de 391.548 hosts quedó cargado en RDS con el SHA y fechas descritos arriba. Sigue siendo histórico y de cobertura parcial. El primer importador tardó varios minutos en el host nuevo sin créditos; se permitió un burst temporal acotado y se restauró `standard` al terminar. Un prefiltro IP evita enviar hostnames DNS al parser de direcciones y limita la longitud; el barrido local de 392.178 filas tomó 0,40 segundos. Ese tiempo no mide una ingesta completa en RDS.

La cadena privada Nginx → BFF → API → RDS responde 200/201, aplica CSP y permite crear un intento OIDC con PKCE. Managed login acepta `prompt=login` y `max_age=0`, sin acreditar todavía reautenticación interactiva. Las pruebas sintéticas no se suman a consultas reales en las métricas.

## Verificación pública

El 17-oct se creó un Tunnel administrado y su DNS proxied exclusivo para el hostname del proyecto. El conector usa una credencial propia cifrada en SSM; el token administrativo permanece fuera de EC2. La CLI oficial `cf` y las credenciales se documentan en `devops-agents`.

HTTPS respondió 200 con CSP, HSTS y `Cache-Control: no-store`; HTTP redirige a HTTPS con 308 sólo en el hostname del proyecto. La consulta sintética devolvió 201 y veredicto inconcluso; una escritura desde otro origen fue rechazada con 403. Chrome mostró la consulta de ejemplo bancaria como alto riesgo y cargó el managed login de Cognito. En una ventana privada, el ejemplo familiar devolvió sospechoso y recomendó llamar al número previamente guardado. `/auth/login` devolvió 303 con PKCE S256, state y cookie Secure. Los ejemplos se contabilizan como demostraciones, sin incrementar consultas reales.

Pendientes de integración: recorrido OIDC completo en navegador público y ejercicio de restauración de backups. El piloto Contributor de contexto completo quedó publicado y activado posteriormente, según el registro al final.

## Refinamiento local tras pruebas de uso

La portada explica el problema antes del formulario. Guía, ejemplos ficticios y preguntas frecuentes se movieron a `/como-funciona`, accesible desde la navegación. La columna izquierda queda limitada al alto de la ventana. El resultado usa motivos numerados con títulos y explicaciones de16px, direcciones y límites separados, evidencia y ayuda desplegables, guardado explícito y feedback breve. Se retiraron el contador inicial de turnos y las métricas diarias visibles; sus límites y conteos siguen en servidor. Sin carga de imágenes todavía. Ver [decisiones de experiencia](../design/experience.md#ajustes-tras-la-prueba-desplegada-de-jp-17-oct).

Tipos y build correctos, 45 pruebas Node y 102 Phoenix aprobadas. Revisión manual en Chrome de portada, consulta, ayuda por datos compartidos y pago, explicación del guardado y presentación a 390px. Los selectores E2E se ajustaron al nuevo contenido; la suite completa de navegador no se volvió a ejecutar en esta revisión. Cambios locales pendientes de commit/push y despliegue.


## Comprobación de sitios y Contributor, corte local

`Destination` resuelve DNS A, exige que todas las respuestas sean IPv4 públicas y fija la conexión a una IP validada. Mint conserva hostname, SNI y verificación del certificado. HEAD consulta sólo `/`, sin userinfo, ruta, query, fragmento, cookies o credenciales. Sólo puertos80/443, máximo tres sitios por recorrido, encabezados16KiB, plazos por conexión/respuesta y límite exterior de4s por enlace. Cada redirección se valida de nuevo; se bloquean redes privadas, loopback, metadata AWS, IPv6 y destinos locales. No se sigue una bajada HTTPS a HTTP. Una redirección dentro del mismo host no provoca una visita a su ruta.

Los acortadores de la lista permitida conservan su resolución previa mediante HEAD del enlace completo. Tanto esos hosts intermedios como los observados al comprobar raíces se comparan con el feed por host exacto. Los nuevos hosts reciben comprobaciones locales de imitación; las redirecciones a otro dominio son una señal adicional débil. El resultado guardado conserva sólo dominios registrables, nunca subdominios identificadores, rutas o parámetros. No se descarga HTML, no se ejecuta JavaScript y no se conoce la cadena de la ruta concreta de un sitio arbitrario. Una respuesta HTTP sólo acredita que hubo respuesta en esa comprobación. Con red habilitada, una comprobación de sitio incompleta impide un resultado verde; la cobertura distingue ese estado.

Por instrucción expresa de JP, el piloto interno envía `message` original y `analysis` completo, incluidas señales, dominios, cobertura, resultado de reglas y consejos. Las preguntas de seguimiento se envían completas con el resultado disponible, sin recuperar el original porque no se conserva. Las categorías de interacción siguen usando acciones locales. El modelo puede interpretar lenguaje sin señales deterministas; esa elevación queda limitada a sospechoso y no rebaja reglas. Las pruebas verifican igualdad del payload con el texto y el análisis, conservación de5.000 caracteres Unicode y ausencia del original en PostgreSQL. Antes de abrir al público general se cambiará el modelo/modalidad.

Prueba de integración local: consulta ficticia con `https://www.viabcp.com/`, BFF201, sitio `completed`, IA `completed` y `signals_and_ai`. Revisión visual en Chrome de motivos independientes, sidebar y guía separada. Al recargar la API con el corte final, otra consulta conservó señales con IA no disponible y sitio completado. El adaptador anterior de códigos cerrados volvió a responder HTTP200 en4.402ms con códigos ficticios; no se garantiza disponibilidad ni se añaden reintentos automáticos. El modelo C4 y sus exportaciones PlantUML/SVG se actualizaron para incluir los sitios consultados y la entrada completa de Contributor para el piloto interno; Structurizr valida. Sólo datos sintéticos. La versión pública conserva las imágenes anteriores y la IA desactivada hasta commit, publicación y despliegue.

Referencias de implementación: [OWASP SSRF](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html), [Mint HTTP](https://mint.hexdocs.pm/Mint.HTTP.html) y [contrato Contributor](../architecture/ai-interpretation.md).


## Piloto interno de contexto completo

JP indicó que las pruebas de los próximos días son internas de hackathon y autorizó enviar todo el mensaje y su contexto a Muse Spark Contributor. Esta decisión sustituye la restricción anterior a códigos. La salida continúa siendo categorías e ids validados; no se muestra prosa generada ni se atribuye una vulnerabilidad comprobada al modelo. El mensaje sólo vive en memoria durante el análisis, fuera de resultados persistidos y logs.

Los ejemplos dejaron el home y se integraron en las tarjetas de `/como-funciona`. Sus enlaces preparan una consulta mediante ids cerrados `bank`/`family`, sin ejecutar análisis automáticamente. La suite E2E quedó adaptada al nuevo recorrido y compiló, pero no se volvió a ejecutar completa. Validación de este corte:102 Phoenix,45 Node y tipos/build correctos.

Prueba del contexto completo desde Chrome: /como-funciona → ejemplo bancario → formulario preparado → Revisar mensaje → caso completado con signals_and_ai y coverage.ai=completed. Veredicto alto riesgo conservado; destino .example no disponible y cobertura parcial, como corresponde a un fixture. Home sin ejemplos y tarjetas de guía revisadas visualmente.


## Publicación del corte39b20a1

El corte de UI, guía separada, comprobación de sitios y adaptador de contexto completo se publicó y desplegó mediante [CI](https://github.com/deep-skill/everyday-trust/actions/runs/39098407864), [imágenes GHCR](https://github.com/deep-skill/everyday-trust/actions/runs/39098426362) y [deploy AWS](https://github.com/deep-skill/everyday-trust/actions/runs/39098550194), todos correctos. La imagen ejecutada corresponde a39b20a1cb07233fc99d80df871e7de0adde739de. Los cambios posteriores de documentación no requieren reconstruir esa imagen.

La verificación pública acreditó HTTPS200 con CSP/HSTS/no-store, HTTP308, guía200 sin ejemplos en el home, PKCE303, escritura desde otro origen403, ejemplo bancario de alto riesgo y raíz oficial completada. Sólo ejemplos ficticios, marcados como demostraciones. La IA permaneció desactivada; su activación general en esta URL pública queda pendiente de definir el alcance del piloto. Secretos, flags, digests y evidencia operativa en devops-agents. No se acredita con esto el recorrido OIDC completo de cuenta ni restore.

## Activación del piloto público, 18-oct

JP autorizó expresamente habilitar Muse Spark Contributor en la URL pública sin login y enviar el contexto completo. Se conservaron las credenciales y las imágenes de aplicación39b20a1. El [despliegue de activación](https://github.com/deep-skill/everyday-trust/actions/runs/39100734515) terminó correctamente. La comprobación pública con ejemplos ficticios acreditó IA completada, alto riesgo bancario conservado y raíz oficial completada, además de HTTPS, guía, PKCE y rechazo de escrituras desde otro origen. El chequeo privado de arranque ahora tiene intentos acotados para tolerar la recreación de la API; no añade reintentos al proveedor de IA.

Una repetición posterior completó la IA del caso bancario, pero no la del enlace oficial, y el chequeo estricto falló. La activación no garantiza disponibilidad del proveedor; la aplicación conserva las señales y declara cobertura incompleta cuando la IA falla. No se amplió el plazo ni se añadieron llamadas automáticas para ocultar ese resultado.

Por solicitud de JP, se detuvo el entorno local y se cerró Docker Desktop. Se eliminaron dependencias, compilaciones y caché regenerables, conservando fuentes, credenciales y volúmenes de datos. La aplicación AWS continúa operativa; para retomar desarrollo local se reinstalan dependencias y se levanta Compose según el README. El detalle de limpieza queda en devops-agents.


## Tracción, reseñas y pitch,18-oct

Corte3afb181: métricas discretas al pie, visitas aproximadas por sesión y consultas completadas, sin exponer UTC ni cuotas en la portada. Los totales excluyen demostraciones. Las reseñas requieren el caso completado y su sesión/titular; se validan estrellas y longitud, hay cuotas y un índice único impide duplicados. Sólo se publica el promedio agregado; el comentario llega al equipo, no al modelo. Retención30d y borrado con cuenta, manteniendo agregados anónimos. El modo demo también separa sus reseñas de la tracción.

Cognito ya permitía cuenta e historial. Chrome privado comprobó acceso, análisis, guardado y lectura de historial con una identidad sintética sin emails/SMS. El formulario nativo de Salir falló por Origin:null causado por no-referrer. Se cambió Referrer-Policy a same-origin, manteniendo CSRF. HTTP comprobó logout303 desde el origen propio y403 desde origen ajeno o null. La repetición visual final y revisión del componente nuevo quedaron bloqueadas por cgWindowNotFound en Chrome y Firefox; no se anuncian como aprobadas. El registro con confirmación de correo real y la recuperación de contraseña no se probaron con un buzón real.

CI39102532151 pasó108 Phoenix y45 Node. Imágenes39102641782 construidas con amd64 nativo, SBOM y provenance. El añadido de evaluación, sin cambios al código de aplicación, pasó en CI39102714048 con109 Phoenix/45 Node:24 fixtures offline,0 verdes peligrosos,0 falsas alarmas y6 abstenciones. No mide precisión real ni desempeño de IA.

Despliegue final39103055072 exitoso, mismas imágenes3afb181. Se validó Nginx antes de migrar y se asignaron permisos mínimos explícitos de la nueva tabla al rol API, sin ampliar IAM. Comprobación pública: caso bancario demo de alto riesgo con IA completada, reseña idempotente, comentario privado y retirado, aislamiento entre sesiones, cinco slides y SVG públicos200. Una visita técnica se verificó con dos peticiones y se excluyó después. Ráfaga acotada de30 lecturas de health:18 respuestas200 y12 con429; no fue prueba de carga y no llamó al modelo. Detalle operativo en devops-agents.

[Presentación HTML](../presentation/index.html): cinco slides revisadas en Chrome local antes de perder el control visual, símbolos originales AWS, flechas animadas con pausa/movimiento reducido y notas de tres minutos. Publicada en /presentacion/ y registrada como URL de presentación de la entrega del evento. Borradores de comentario y posts personales en docs/launch/social-copy.md; menciones exactas pendientes de JP.


Ajuste posterior155516f: el botón Salir usa un POST al mismo origen que devuelve el destino de salida en JSON y luego navega a Cognito. Conserva form-action self, el chequeo de origen, el borrado de sesión y la revocación. Evita depender de cómo cada navegador aplica la CSP a una redirección de formulario. Tipos/build y45 Node pasaron en local. El diagrama y slides no cambiaron. La repetición visual sigue pendiente del control de ventanas.


Cierre155516f: CI39103396264 (109 Phoenix/45 Node), imágenes39103413549 y deploy39103553328 correctos. La verificación pública final repitió reseña demo/privacidad/titularidad y acreditó logout JSON200 con redirect_to, formulario303, origen ajeno/null403, HTTPS/CSP/HSTS/no-store, Referrer-Policy same-origin y Cognito lang=es. IA del caso demo completada. La visita técnica quedó excluida y la identidad QA con sus datos/sesión fue eliminada. El control visual sigue no disponible, por lo que ese último recorrido no se declara probado en navegador. No se enviaron posts en redes: faltan enlaces/menciones exactos de JP y navegador disponible.


## Registro de validaciones trasladado del README

Registro histórico; consultar el estado actual al inicio del documento.

Web pública: **[verifica.deepskill.space](https://verifica.deepskill.space)**. Implementación desplegada en AWS: SvelteKit/TypeScript/Tailwind, BFF Node, API Elixir/Phoenix, RDS PostgreSQL privado y Cognito Essentials. Incluye OIDC/PKCE, cookies opacas, tokens cifrados, autorización por propietario, cuotas atómicas, vencimiento y borrado. El corte desplegado tiene108 pruebas Phoenix y45 Node aprobadas, también verificadas por CI. La suite de navegador acreditó previamente 29 comprobaciones con identidad simulada; no se volvió a ejecutar completa en este refinamiento. Otras 12 comprobaciones integran Cognito y RDS reales con dos cuentas sintéticas, eliminadas al finalizar y sin envío de emails/SMS. Se comprobaron acceso Cognito, guardado y lectura de historial en Chrome privado. El cierre de sesión se corrigió y pasó por HTTP; su repetición visual quedó pendiente al perderse el control de ventanas.

CI, imágenes amd64 en GHCR y despliegue AWS por OIDC/SSM ejecutados correctamente. EC2 no tiene puertos entrantes; Cloudflare Tunnel sirve el acceso público. Se verificaron la página y una consulta anónima en Chrome, además de HTTPS, CSP, consulta por API y redirección PKCE a Cognito. La [implementación](../architecture/implementation.md) distingue estas capacidades de la [arquitectura objetivo](../architecture/aws-deployment.md).

[Presentación pública de cinco slides](https://verifica.deepskill.space/presentacion/), con fuente HTML en [docs/presentation](../presentation/README.md), diagrama SVG con símbolos AWS y notas para tres minutos. La entrega del evento referencia esa URL. [Evaluación sintética reproducible](../architecture/evaluation-report.json):24 casos offline,0 verdes peligrosos,0 falsas alarmas y6 abstenciones; no estima precisión real ni calidad del modelo. CI del código con la evaluación:109 pruebas Phoenix y45 Node.
